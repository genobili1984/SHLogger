//
//  LogBuffer.h
//  AFNetworking
//
//  Created by Genobili Mao on 2018/10/12.
//

#ifndef LOGBUFFER_H_
#define LOGBUFFER_H_

#include <stddef.h>
#include "ptrbuffer.h"
#include "autobuffer.h"

class LogBuffer {
public:
    LogBuffer(void* _pbBuffer, size_t _len);
    ~LogBuffer();
    
public:
    PtrBuffer& GetData();
    
    void Flush(AutoBuffer& _buffer);
    //bool Write(const void* _data, size_t _inputLen, AutoBuffer& _out_buff);
    bool Write(const void* _data, size_t _inputLen);
    
private:
    bool __Reset();
    void __Flush();
    void __Clear();
    
    void __Fix();
    
    
private:
    PtrBuffer buff_;
    
};


#endif
