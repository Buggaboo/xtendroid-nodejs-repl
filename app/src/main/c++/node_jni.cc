/*
 * Copyright (C) 2009 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#include "node.h"
#include "node_jni.h"

#include <string.h>
#include <jni.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <android/log.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

using namespace node;

#if defined(__arm__)
  #if defined(__ARM_ARCH_7A__)
    #if defined(__ARM_NEON__)
      #define ABI "armeabi-v7a/NEON"
    #else
      #define ABI "armeabi-v7a"
    #endif
  #else
   #define ABI "armeabi"
  #endif
#elif defined(__i386__)
   #define ABI "x86"
#elif defined(__mips__)
   #define ABI "mips"
#else
   #define ABI "unknown"
#endif

/**
 * Ol' dirty trick to convert const char* to char*
 */
union charunion {
  char *chr;
  const char* cchr;
};

using namespace node;


#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT jint JNICALL Java_nl_sison_android_nodejs_repl_NodeJNI_start
  (JNIEnv *env, jclass clazz, jint jargc, jobjectArray jargv)
{
    
    int len = env->GetArrayLength(jargv); // should be equal to argc

    char** argv = new char*[len];
    jstring* jstringArr = new jstring[len];


    // type conversion, wow
    fprintf(stdout, "argc:%i\n", (int) jargc);
    for (int i=0; i<len; i++) {
        jstringArr[i] = (jstring) env->GetObjectArrayElement(jargv, i);
        charunion char_union;
        char_union.cchr = env->GetStringUTFChars(jstringArr[i], 0);
        argv[i] = char_union.chr;

        // debug
        fprintf(stdout, "%s\n", argv[i]); // stdout is /dev/null on Android        
    }

    // capture exit result
    int returnValue = node::Start((int) jargc, argv);
    // TODO jint is a typedef for long on an arm64/amd64 and how about endianness? Phrack it. Just cast.
    // figure out with macros later

    for (int i=0; i<len; i++) {
        // prevent memory leaks
        env->ReleaseStringUTFChars(jstringArr[i], argv[i]);
    }
    
    // deallocate arrays
    delete argv;
    delete jstringArr;

    return returnValue;
}


#ifdef __cplusplus
}
#endif

