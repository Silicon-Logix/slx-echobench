// Silicon LogiX / SLX EchoBench
// Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
// Author: Marco Pezzullo
// License: Silicon LogiX Evaluation License 1.0. See LICENSE.
// Public data interchange only: no signal model or inspection algorithm.
#include <nlohmann/json.hpp>
#include <hdf5.h>
#include <windows.h>
#include <bcrypt.h>
#include <array>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <vector>
using json=nlohmann::json;
namespace fs=std::filesystem;
constexpr const char* mapping="slx.echobench.nde-single-ascan/v1";
constexpr const char* dataset_path="/Public/Groups/0/Datasets/0-AScanAmplitude";
constexpr size_t max_metadata=64*1024*1024;
void check(bool value){if(!value)throw std::runtime_error("NDE mapping rejected");}
struct H5 {
    hid_t id;herr_t(*close)(hid_t);
    H5(hid_t value,herr_t(*closer)(hid_t)):id(value),close(closer){check(id>=0);}
    ~H5(){close(id);}
    operator hid_t()const{return id;}
    H5(const H5&)=delete;
};
std::string read_bytes(const fs::path& path,size_t limit){check(fs::is_regular_file(path)&&fs::file_size(path)<=limit);std::ifstream file(path,std::ios::binary);return {std::istreambuf_iterator<char>(file),{}};}
json parse(const std::string& value){return json::parse(value,[](int depth,json::parse_event_t,json&){check(depth<=32);return true;});}
std::string digest(const std::string& value){
    BCRYPT_ALG_HANDLE algorithm=nullptr;BCRYPT_HASH_HANDLE hash=nullptr;DWORD length=0,read=0;
    check(BCryptOpenAlgorithmProvider(&algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0)>=0);
    check(BCryptGetProperty(algorithm,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&length),sizeof length,&read,0)>=0);
    std::vector<UCHAR> object(length);std::array<UCHAR,32> output{};
    check(BCryptCreateHash(algorithm,&hash,object.data(),length,nullptr,0,0)>=0);
    check(BCryptHashData(hash,reinterpret_cast<PUCHAR>(const_cast<char*>(value.data())),ULONG(value.size()),0)>=0);
    check(BCryptFinishHash(hash,output.data(),DWORD(output.size()),0)>=0);
    BCryptDestroyHash(hash);BCryptCloseAlgorithmProvider(algorithm,0);
    std::ostringstream text;for(auto byte:output)text<<std::hex<<std::setw(2)<<std::setfill('0')<<int(byte);return text.str();
}
std::string utf8(const fs::path& path){auto s=path.generic_u8string();return {s.begin(),s.end()};}
std::string utc_now(){auto stamp=std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());std::tm date{};gmtime_s(&date,&stamp);std::ostringstream text;text<<std::put_time(&date,"%Y-%m-%dT%H:%M:%SZ");return text.str();}
bool valid_date(const std::string& date){
    if(date.size()!=20||date[4]!='-'||date[7]!='-'||date[10]!='T'||date[13]!=':'||date[16]!=':'||date[19]!='Z')return false;
    for(size_t i=0;i<date.size();i++)if(i!=4&&i!=7&&i!=10&&i!=13&&i!=16&&i!=19&&(date[i]<'0'||date[i]>'9'))return false;
    std::tm value{};std::istringstream text(date);text>>std::get_time(&value,"%Y-%m-%dT%H:%M:%SZ");if(text.fail())return false;auto original=value;
    if(_mkgmtime64(&value)<0)return false;
    return value.tm_year==original.tm_year&&value.tm_mon==original.tm_mon&&value.tm_mday==original.tm_mday&&value.tm_hour==original.tm_hour&&value.tm_min==original.tm_min&&value.tm_sec==original.tm_sec;
}
json properties(const std::string& date){return {{"$schema","Properties-Schema-4.4.0.json"},{"file",{{"creationDate",date},{"formatVersion","4.4.0"},{"createdByAppName","SLX EchoBench synthetic model"},{"createdByAppVersion","0.1.0"},{"createdByAppCompany","Silicon LogiX"},{"notice","Synthetic raw single A-scan; no physical instrument qualification."}}},{"methods",{"UT"}}};}
json setup(const json& frame){
    json axes=json::array({{{"axis","UCoordinate"},{"quantity",1},{"resolution",.001},{"offset",frame.at("pose").at("x_m")},{"unit","m"},{"name","Blender laboratory X"}},{{"axis","VCoordinate"},{"quantity",1},{"resolution",.001},{"offset",frame.at("pose").at("y_m")},{"unit","m"},{"name","Blender laboratory Y"}},{{"axis","Ultrasound"},{"quantity",512},{"resolution",4e-8},{"offset",0}}});
    json dataset={{"id",0},{"name","Selected synthetic RF acquisition"},{"dataClass","AScanAmplitude"},{"storageMode","Paintbrush"},{"dataValue",{{"min",-1},{"max",1},{"unitMin",-100},{"unitMax",100},{"unit","Percent"}}},{"path",dataset_path},{"dimensions",axes}};
    return {{"$schema","Setup-Schema-4.4.0.json"},{"version","4.4.0"},{"scenario","General Mapping"},{"groups",json::array({{{"id",0},{"name","SLX synthetic single A-scan"},{"usage","Raw model output. No hardware acquisition process is asserted. Pose, calibration and session provenance are in /Private/SLX."},{"datasets",json::array({dataset})}}})}};
}
void require_hard_path(hid_t file,const std::string& path){std::string current;std::istringstream parts(path);std::string part;while(std::getline(parts,part,'/'))if(!part.empty()){current+="/"+part;H5L_info2_t info{};check(H5Lget_info2(file,current.c_str(),&info,H5P_DEFAULT)>=0&&info.type==H5L_TYPE_HARD);}}
void require_internal_dataset(hid_t dataset){H5 properties(H5Dget_create_plist(dataset),H5Pclose);check(H5Pget_nfilters(properties)==0&&H5Pget_external_count(properties)==0&&H5Pget_layout(properties)!=H5D_VIRTUAL);}
void write_json(hid_t file,const char* path,const json& value){
    auto text=value.dump();check(!text.empty()&&text.size()<=max_metadata);
    H5 type(H5Tcopy(H5T_C_S1),H5Tclose);check(H5Tset_size(type,text.size())>=0&&H5Tset_cset(type,H5T_CSET_UTF8)>=0&&H5Tset_strpad(type,H5T_STR_NULLPAD)>=0);
    H5 space(H5Screate(H5S_SCALAR),H5Sclose);H5 dataset(H5Dcreate2(file,path,type,space,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT),H5Dclose);check(H5Dwrite(dataset,type,H5S_ALL,H5S_ALL,H5P_DEFAULT,text.data())>=0);
}
json read_json(hid_t file,const char* path){
    require_hard_path(file,path);H5 dataset(H5Dopen2(file,path,H5P_DEFAULT),H5Dclose);require_internal_dataset(dataset);
    H5 space(H5Dget_space(dataset),H5Sclose);H5 type(H5Dget_type(dataset),H5Tclose);size_t length=H5Tget_size(type);
    check(H5Sget_simple_extent_ndims(space)==0&&H5Tget_class(type)==H5T_STRING&&H5Tis_variable_str(type)==0&&length>0&&length<=max_metadata);
    std::string text(length,'\0');check(H5Dread(dataset,type,H5S_ALL,H5S_ALL,H5P_DEFAULT,text.data())>=0);return parse(text);
}
std::array<double,512> rf(const json& frame){
    check(frame.at("raw_q15").is_array()&&frame["raw_q15"].size()==512&&frame.at("result").at("data_valid")==true&&frame.at("dropped_samples")==0&&frame.at("dt_us")==.04);
    std::array<double,512> values{};for(size_t i=0;i<512;i++){auto q=frame["raw_q15"][i];check(q.is_number_integer()&&q.get<int>()>=-32767&&q.get<int>()<=32767);values[i]=q.get<double>()/32767;}return values;
}
json import_file(const fs::path& path){
    check(fs::is_regular_file(path)&&fs::file_size(path)<=128*1024*1024);H5 file(H5Fopen(utf8(path).c_str(),H5F_ACC_RDONLY,H5P_DEFAULT),H5Fclose);
    for(auto [path,count]:std::vector<std::pair<std::string,hsize_t>>{{"/",3},{"/Public",2},{"/Public/Groups",1},{"/Public/Groups/0",1},{"/Public/Groups/0/Datasets",1},{"/Private",1},{"/Private/SLX",1}}){
        if(path!="/")require_hard_path(file,path);H5 group(H5Gopen2(file,path.c_str(),H5P_DEFAULT),H5Gclose);H5G_info_t info{};check(H5Gget_info(group,&info)>=0&&info.nlinks==count);
    }
    auto prop=read_json(file,"/Properties"),metadata=read_json(file,"/Public/Setup"),extension=read_json(file,"/Private/SLX/Session");
    auto date=prop.at("file").at("creationDate").get<std::string>();check(valid_date(date)&&prop==properties(date));
    check(extension.at("mapping")==mapping&&extension.at("source")=="synthetic_software_model"&&extension.at("quantization_bits")==16);
    auto document=extension.at("session_document").get<std::string>();check(document.size()<=max_metadata&&extension.at("session_sha256")==digest(document));auto session=parse(document);
    size_t index=extension.at("selected_index");check(session.at("frames").is_array()&&session["frames"].size()<=4096&&index<session["frames"].size());const auto& frame=session["frames"][index];auto values=rf(frame);
    check(session.at("schema")=="slx.echobench.session/v1"&&session.at("storage_encoding")=="q15_int16"&&metadata==setup(frame)&&extension.at("input_sha256")==frame.at("input_sha256"));
    require_hard_path(file,dataset_path);H5 dataset(H5Dopen2(file,dataset_path,H5P_DEFAULT),H5Dclose);require_internal_dataset(dataset);H5 type(H5Dget_type(dataset),H5Tclose);H5 space(H5Dget_space(dataset),H5Sclose);hsize_t dimensions[3]{};
    check(H5Sget_simple_extent_ndims(space)==3&&H5Sget_simple_extent_dims(space,dimensions,nullptr)>=0&&dimensions[0]==1&&dimensions[1]==1&&dimensions[2]==512&&H5Tequal(type,H5T_IEEE_F64LE)>0);
    std::array<double,512> actual{};check(H5Dread(dataset,H5T_NATIVE_DOUBLE,H5S_ALL,H5S_ALL,H5P_DEFAULT,actual.data())>=0);check(actual==values);
    return {{"ok",true},{"mapping",mapping},{"format_version","4.4.0"},{"selected_index",index},{"session",session},{"schema_validation","strict qualified subset"},{"roundtrip_verified",true}};
}
json export_file(const json& payload,const fs::path& target){
    const auto& session=payload.at("session");size_t index=payload.at("index");check(session.at("schema")=="slx.echobench.session/v1"&&session.at("storage_encoding")=="q15_int16"&&index<session.at("frames").size());const auto& frame=session["frames"][index];auto values=rf(frame);auto document=session.dump();check(document.size()<=max_metadata);
    json extension={{"mapping",mapping},{"selected_index",index},{"source","synthetic_software_model"},{"quantization_bits",16},{"input_sha256",frame.at("input_sha256")},{"session_sha256",digest(document)},{"session_document",document}};
    {
        H5 file(H5Fcreate(utf8(target).c_str(),H5F_ACC_TRUNC,H5P_DEFAULT,H5P_DEFAULT),H5Fclose);
        for(auto group:{"/Public","/Public/Groups","/Public/Groups/0","/Public/Groups/0/Datasets","/Private","/Private/SLX"}){H5 value(H5Gcreate2(file,group,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT),H5Gclose);}
        write_json(file,"/Properties",properties(utc_now()));write_json(file,"/Public/Setup",setup(frame));write_json(file,"/Private/SLX/Session",extension);
        hsize_t dimensions[3]={1,1,512};H5 space(H5Screate_simple(3,dimensions,nullptr),H5Sclose);H5 dataset(H5Dcreate2(file,dataset_path,H5T_IEEE_F64LE,space,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT),H5Dclose);check(H5Dwrite(dataset,H5T_NATIVE_DOUBLE,H5S_ALL,H5S_ALL,H5P_DEFAULT,values.data())>=0);
    }
    check(import_file(target).at("session")==session);
    return {{"ok",true},{"mapping",mapping},{"format_version","4.4.0"},{"selected_index",index},{"dimensions",{1,1,512}},{"input_sha256",frame.at("input_sha256")},{"schema_validation","strict qualified subset"},{"roundtrip_verified",true}};
}
int wmain(int argc,wchar_t** argv){
    if(argc!=5)return 2;
    H5Eset_auto2(H5E_DEFAULT,nullptr,nullptr);H5PLset_loading_state(0);json result;
    try{std::wstring operation=argv[1];if(operation==L"export")result=export_file(parse(read_bytes(argv[2],max_metadata)),argv[3]);else{check(operation==L"import");result=import_file(argv[2]);}}
    catch(...){result={{"ok",false},{"code","NDE_MAPPING_REJECTED"},{"message","Unsupported or inconsistent NDE single-A-scan mapping. The current session is unchanged."}};}
    std::ofstream output(fs::path(argv[4]),std::ios::binary);output<<result.dump();output.close();return result["ok"]==true&&output?0:1;
}
