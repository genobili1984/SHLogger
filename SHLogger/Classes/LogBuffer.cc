//
//  LogBuffer.m
//  AFNetworking
//
//  Created by Genobili Mao on 2018/10/12.
//

#include "LogBuffer.h"
#include "stddef.h"

LogBuffer::LogBuffer(void* _pbBuffer, size_t _len) {
    buff_.Attach(_pbBuffer, _len);
    __Fix();
}

LogBuffer::~LogBuffer()  {
    
}

PtrBuffer& LogBuffer::GetData() {
    return buff_;
}

void LogBuffer::Flush(AutoBuffer& _buff) {
    __Flush();
    _buff.Write(buff_.Ptr(), buff_.Length());
    __Clear();
}

bool LogBuffer::Write(const void* _data, size_t _length)  {
    if( NULL == _data  || 0 == _length ) {
        return false;
    }
    if( buff_.Length() == 0 ) {
        if( !__Reset() ) {
            return false;
        }
    }
    buff_.Write(_data, _length);
    return true;
}

bool LogBuffer::__Reset() {
    __Clear();
    return true;
}

void LogBuffer::__Flush() {
    
}

void LogBuffer::__Clear() {
    memset(buff_.Ptr(), 0, buff_.MaxLength());
    buff_.Length(0,0);
}

void LogBuffer::__Fix() {
    buff_.Length(0, 0);
}


















