// Silicon LogiX / SLX EchoBench
// Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
// License: Silicon LogiX Evaluation License 1.0. See LICENSE.
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.Bus;

namespace Antmicro.Renode.Peripherals.Miscellaneous
{
    // A deliberately small virtual ADC/FIFO register contract. The RTL path calls
    // a Verilator-compiled library on each handshake; it is not a block animation.
    public class EchoAcquisition : IDoubleWordPeripheral, IKnownSize
    {
        public EchoAcquisition(IMachine machine) { this.machine=machine; Reset(); }
        public void Reset() { data.Clear(); position=0; flags=0; rtl=false; }
        public void LoadSamples(string path, bool useRtl, bool burst)
        {
            Reset();rtl=useRtl;var bytes=File.ReadAllBytes(path);
            if(bytes.Length!=1024) throw new ArgumentException("Exactly 512 Q15 samples required");
            for(int i=0;i<512;i++) data.Add(BitConverter.ToInt16(bytes,2*i));
            if(rtl) FifoReset();
            if(burst)
            {
                if(rtl) {foreach(var value in data) FifoPush(value); flags=(uint)FifoDropped();}
                else flags=256;
            }
            this.burst=burst;
        }
        public uint ReadDoubleWord(long offset)
        {
            switch(offset)
            {
                case 0: return (uint)(burst?256:512);
                case 4:
                    if(position>= (burst?256:512)) return 0;
                    short value=data[position++];
                    if(rtl){if(!burst)FifoPush(value);value=(short)FifoPop();}
                    return (uint)(ushort)value;
                case 8: return flags>0?1u:0u;
                case 12: return gateStart;
                case 16: return gateEnd;
                case 20: return gateThreshold;
                default: return 0;
            }
        }
        public void WriteDoubleWord(long offset,uint value) { }
        public void Configure(uint start,uint end,uint threshold)
        { gateStart=start;gateEnd=end;gateThreshold=threshold; }
        public void SaveResults(string path)
        {
            var bus=machine.GetSystemBus(this);
            var values=new string[9];
            for(int i=0;i<9;i++) values[i]=bus.ReadDoubleWord(0x20018000+(ulong)(i*4)).ToString();
            File.WriteAllText(path,"["+String.Join(",",values)+"]");
        }
        public long Size { get { return 0x100; } }
        [DllImport("slx_echo_fifo",EntryPoint="echo_fifo_reset")] private static extern void FifoReset();
        [DllImport("slx_echo_fifo",EntryPoint="echo_fifo_push")] private static extern int FifoPush(int value);
        [DllImport("slx_echo_fifo",EntryPoint="echo_fifo_pop")] private static extern int FifoPop();
        [DllImport("slx_echo_fifo",EntryPoint="echo_fifo_dropped")] private static extern int FifoDropped();
        private readonly List<short> data=new List<short>();
        private int position;
        private uint flags;
        private bool rtl,burst;
        private readonly IMachine machine;
        private uint gateStart=50,gateEnd=290,gateThreshold=9175;
    }
}
