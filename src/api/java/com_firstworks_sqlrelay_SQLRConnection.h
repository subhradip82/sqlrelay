/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class com_firstworks_sqlrelay_SQLRConnection */

#ifndef _Included_com_firstworks_sqlrelay_SQLRConnection
#define _Included_com_firstworks_sqlrelay_SQLRConnection
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    delete
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_delete
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    setTimeout
 * Signature: (II)V
 */
JNIEXPORT void JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_setTimeout
  (JNIEnv *, jobject, jint, jint);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    endSession
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_endSession
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    suspendSession
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_suspendSession
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    getConnectionPort
 * Signature: ()S
 */
JNIEXPORT jshort JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_getConnectionPort
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    getConnectionSocket
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_getConnectionSocket
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    resumeSession
 * Signature: (SLjava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_resumeSession
  (JNIEnv *, jobject, jshort, jstring);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    ping
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_ping
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    identify
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_identify
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    dbVersion
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_dbVersion
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    serverVersion
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_serverVersion
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    clientVersion
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_clientVersion
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    bindFormat
 * Signature: ()Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_bindFormat
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    selectDatabase
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_selectDatabase (JNIEnv *env, jobject self, jstring database);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    autoCommitOn
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_autoCommitOn
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    autoCommitOff
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_autoCommitOff
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    commit
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_commit
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    rollback
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_rollback
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    debugOn
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_debugOn
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    debugOff
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_debugOff
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    getDebug
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_getDebug
  (JNIEnv *, jobject);

/*
 * Class:     com_firstworks_sqlrelay_SQLRConnection
 * Method:    alloc
 * Signature: (Ljava/lang/String;SLjava/lang/String;Ljava/lang/String;Ljava/lang/String;II)J
 */
JNIEXPORT jlong JNICALL Java_com_firstworks_sqlrelay_SQLRConnection_alloc
  (JNIEnv *, jobject, jstring, jshort, jstring, jstring, jstring, jint, jint);

#ifdef __cplusplus
}
#endif
#endif
