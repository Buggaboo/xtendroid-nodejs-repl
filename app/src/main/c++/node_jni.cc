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
    
JNIEXPORT jintArray JNICALL Java_nl_sison_android_nodejs_repl_NodeJNI_redirectStdio
  (JNIEnv* env, jclass thiz, jstring jOutfile, jstring jInfile)
{
    const char* outfile = env->GetStringUTFChars(jOutfile, 0);
    const char* infile = env->GetStringUTFChars(jInfile, 0);
    
    /* TODO also create stderr? */

    /*
     * Step 1: Make a named pipe
     * Step 2: Open the pipe in Write only mode. Java code will open it in Read only mode.
     * Step 3: Make STDOUT i.e. 1, a duplicate of opened pipe file descriptor.
     * Step 4: Any writes from now on to STDOUT will be redirected to the the pipe and can be read by Java code.
     */
    int out = mkfifo(outfile, 0664);
    int fdo = open(outfile, O_WRONLY);

    int in = mkfifo(infile, 0664); // Make named input file here for synchronization

    dup2(fdo, 1);
    setbuf(stdout, NULL); // TODO investigate setvbuf
//  fprintf(stdout, "%s", outfile); // test code
//  fprintf(stdout, "\n");

    /*
     * Step 1: Make a named pipe
     * Step 2: Open the pipe in Read only mode. Java code will open it in Write only mode.
     * Step 3: Make STDIN i.e. 0, a duplicate of opened pipe file descriptor.
     * Step 4: Any reads from STDIN, will be actually read from the pipe and JAVA code will perform write operations.
     */
    int fdi = open(infile, O_RDONLY);
    dup2(fdi, 0);
    
    // send fdi and fdo (file handles, int type) back
    jintArray result = env->NewIntArray(2);
    if (result == NULL) {
        return NULL; /* out of memory error thrown */
    }
    
    // all of this to return a tuple...
    jint fill[2];
    fill[0] = fdo;
    fill[1] = fdi;
    
    // move from the temp structure to the java structure
    env->SetIntArrayRegion(result, 0, 2, fill);
        
    env->ReleaseStringUTFChars(jOutfile, outfile);
    env->ReleaseStringUTFChars(jInfile, infile);
    
    return result; // return array
}  


JNIEXPORT jint JNICALL Java_nl_sison_android_nodejs_repl_NodeJNI_stopRedirect
  (JNIEnv* env, jclass thiz, jint jfdi, jint jfdo)
{
    // close proxy in
    int in_result = close((int) jfdi);
    
    // flush unconsumed bytes, close proxy out
    fflush(stdout);
    int out_result = close((int) jfdo);
    
    return in_result + out_result;
}

/*
 * Shamelessly borrowed from [manishcm/Redirection-JNI](https://github.com/manishcm/Redirection-JNI)
 */
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

