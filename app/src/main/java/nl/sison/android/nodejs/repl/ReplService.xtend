package nl.sison.android.nodejs.repl

import java.io.InputStream
import java.io.OutputStream

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.FileDescriptor

import java.io.BufferedInputStream

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.util.Log
import android.widget.Toast
import android.os.IBinder

import android.net.LocalSocket
import android.net.LocalServerSocket
import android.net.LocalSocketAddress
import android.text.TextUtils
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.HandlerThread
import android.os.Bundle
import android.widget.TextView
import android.widget.EditText

import android.content.Context

import org.apache.http.util.ByteArrayBuffer

import nl.sison.android.nodejs.repl.NodeJNI

import org.xtendroid.annotations.AddLogTag

import org.xtendroid.annotations.CustomView

/**
 * Before & After modifications to pipe.c in libuv
 *
 * Before:
 * 02-16 05:23:56.235  16058-16084/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_bind::fd:78, pipe_fname:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:110
 * 02-16 05:23:56.265  16058-16084/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_connect::fd:78, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:110
 * 02-16 05:23:56.285  16058-16084/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_bind::fd:78, pipe_fname:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:110
 * 02-16 05:25:15.425  16058-16084/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_connect::fd:80, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:110
 *
 * After:
 * 02-16 06:35:07.465  28188-28203/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_bind::fd:78, pipe_fname:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:63
 * 02-16 06:35:07.505  28188-28203/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_connect::fd:78, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:63
 * 02-16 06:35:07.525  28188-28203/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_bind::fd:78, pipe_fname:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:63
 * 02-16 06:37:01.145  28188-28203/nl.sison.android.nodejs.repl D/iojs/android﹕ uv_pipe_connect::fd:80, saddr.sun_path:/data/data/nl.sison.android.nodejs.repl/cache/node-repl.sock, sizeof saddr:63
 */

@CustomView
class ReplTextView extends RobotoRegularTextView implements Handler$Callback
{
    public static String KEY_RESULT = 'result'

    /**
     * First in the sequence of lifecycle onEvents
     */
    override onAttachedToWindow()
    {
        super.onAttachedToWindow

    }

    override onDetachedFromWindow()
    {
        super.onDetachedFromWindow
        ReplWorker.instance.quit
    }

    override init(Context context)
    {
        super.init(context)
    }

    /**
     * Receive m : Message, and process that in the ui thread
     */
    override boolean handleMessage(Message msg)
    {
        this.post[ ReplTextView.this.text = TextUtils.concat(ReplTextView.this.text, msg.data.getString(KEY_RESULT)) ]
        return true
    }
}

/**
 * This will be added to the Activity
 * Inspired by http://stackoverflow.com/questions/4838207/how-to-create-a-looper-thread-then-send-it-a-message-immediately
 */
@AddLogTag
final class ReplWorker extends HandlerThread implements Handler$Callback
{
    Handler$Callback mCallback
    String mSocketName

    var mMainHandler = new Handler(Looper.getMainLooper())

    /**
     * Singleton without private initialization, because Xtend won't allow it
     */
    public static var ReplWorker instance
    public static def create(String socketName, Handler$Callback cb)
    {
        if (instance == null)
        {
            instance = new ReplWorker(socketName, cb)

            // kickstart the process, including setting up the looper
            instance.start
        }
    }

    // TODO add special xml attrib for setting the socketName
    // new NodeReplWorker(cacheDir + '/node-repl.sock, textView)
    new(String socketName, Handler$Callback textView)
    {
        super("NodeReplWorker::" + socketName, android.os.Process.THREAD_PRIORITY_URGENT_DISPLAY)

        mSocketName = socketName
        mCallback = textView
    }

    Thread mThread
    LocalSocket mSocket

    // This will run the show eventually
    Handler mHandler
    Handler mViewHandler

    override onLooperPrepared()
    {
        mSocket = new LocalSocket
        mThread = new Thread ([
            connectLocalSocket()
        ])

        mThread.start()

        // target this object, ReplWorker.instance.write()
        mHandler = new Handler(looper, mCallback)
        mViewHandler = new Handler(looper, this)
    }

    OutputStream mOutputStream
    InputStream  mInputStream
    BufferedInputStream mBis

    val bufferSize = 512
    val buffer = newByteArrayOfSize(bufferSize)
    val mBaf = new ByteArrayBuffer(50);

    /**
     * Run on a seperate thread
     */
    def connectLocalSocket()
    {
        var namespace = LocalSocketAddress.Namespace.FILESYSTEM
        var address = new LocalSocketAddress(mSocketName, namespace)
        val MAX_ATTEMPTS = 10
        var attempts = 0
        while (!mSocket.connected)
        {
            try
            {
                attempts++
                mSocket.connect(address)
            }catch (Throwable t)
            {
                mMainHandler.post([
                    Log.e(TAG, t.message)
                ])
                Thread.sleep(3000) // try again in 3s
            }

            if (attempts > 10)
            {
                mMainHandler.post([
                    val errorExceededAttempts = String.format("Max allowed connection attempts (%d) to %s exceeded, aborting.", MAX_ATTEMPTS, mSocketName)
                    Log.e(TAG, errorExceededAttempts)
                    // mTextView.text = errorExceededAttempts // TODO pass Message to mCallback
                ])

                return
            }
        }

        // happy flow
        setupLocalSocketStreams
    }

    /**
     * Run on a seperate thread
     */
    def setupLocalSocketStreams()
    {
        mMainHandler.post([
            Log.d(TAG, String.format("bound:%b\tconnected:%b", mSocket.bound, mSocket.connected))
        ])

        mOutputStream = mSocket.outputStream // TODO test if necessary to run this on the ui thread
        mInputStream  = mSocket.inputStream

        // urlConn.inputStream signals the outputStream is ready to be sent
        mBis = new BufferedInputStream(mInputStream) // socket in (receive)
    }

    /**
     * Utility method
     */
    static def write(String statement, Handler handler)
    {
        val msg = new Message()
        val bundle = new Bundle
        bundle.putString(ReplTextView.KEY_RESULT, statement)
        msg.data = bundle
        handler.dispatchMessage(msg)
    }

    /**
     * Target this instance, EditText uses this as an entry point
     */
    public def write(String statement)
    {
        write(statement, mHandler)
    }

    // Looper controls the non-ui thread
    override boolean handleMessage(Message msg)
    {
        write(processStatement(msg.data.getString(ReplTextView.KEY_RESULT)), mViewHandler)
        return true
    }

    def processStatement(String statement) {
        if (!TextUtils.isEmpty(statement))
        {
            mOutputStream.write(statement.bytes)
            mOutputStream.flush
        }

        var read = -1
        var flag = true

        while(flag)
        {
            read = mBis.read(buffer)
            if (read == -1) {
                flag = false // superhack since we don't have break/continue
            }else
            {
                mBaf.append(buffer, 0, read)
            }
        }

        return new String(mBaf.toByteArray, 'UTF-8')
    }

    /**
     * Code cleanup section
     *
     * Assume that if the socket is open, all the buffers are also open
     */
    def close()
    {
        if (mSocket != null)
        {
            mSocket.close
            mOutputStream.close
            mInputStream.close
            mBis.close
            //mBaf.close
        }
    }

    override quit()
    {
        super.quit
        close
        return true
    }

    override quitSafely()
    {
        super.quitSafely
        close
        return true
    }

}

@AddLogTag
class ReplService extends Service {

	override onBind(Intent intent) {
		return myBinder
	}

	val private IBinder myBinder = new ReplBinder(this)

	static class ReplBinder extends Binder {

	    ReplService service

	    new (ReplService service)
	    {
	        this.service = service
	    }

		def public ReplService getService() {
			return service
		}
	}

	override onCreate() {
		super.onCreate()

		// TODO kickstart sensors with LocalServerSocket
        // TODO redo this as a Reloading the lib kills existing processes
        new Thread ([
            NodeJNI.start(2, #["nodejs", createCacheFile("http_and_sock_repl.js").absolutePath ]) // runs succesfully
        ]).start()
	}

	/**
	 * Leverage reflection to call ZygoteInit#createFileDescriptor
	 *
	 * I don't exactly know why I coded this, but I have a feeling
	 * it might come in handy later, when getting an android...FileDescriptor
	 * for fds created from node.
	 */
	def createFileDescriptor(int fdi)
	{
        var cls = Class.forName('com.android.internal.os.ZygoteInit')
        /*
        for (m : cls.declaredMethods)
        {
            Log.d(TAG, m.toString)
        }
        */
        var method = cls.getDeclaredMethod('createFileDescriptor', Integer.TYPE)
        method.accessible = true
        return method.invoke(null, #[ fdi ]) as FileDescriptor
	}

	override int onStartCommand(Intent intent, int flags, int startId) {
		super.onStartCommand(intent, flags, startId)
		return START_STICKY
	}

	public def IsBoundable()
	{
	    return true // wtf is this supposed to do?
	}

    /**
     * The alternative way to enter code in nodejs/iojs
     */
    def File createCacheFile(String filename)
    {
         val cacheFile = new File(cacheDir, filename)
/*
         // always load fresh files
         if (cacheFile.exists()) {
          return cacheFile
         }
*/
         var InputStream inputStream = null
         var FileOutputStream fileOutputStream = null

         try {

          inputStream = assets.open("js/" + filename)
          fileOutputStream = new FileOutputStream(cacheFile)

          val bufferSize = 1024
          var buffer = newByteArrayOfSize(bufferSize)
          var length = -1

          while ( (length = inputStream.read(buffer)) > 0) {
              fileOutputStream.write(buffer,0,length)
          }

         } catch (FileNotFoundException e) {
          e.printStackTrace()
         } catch (IOException e) {
          e.printStackTrace()
         }finally {
          try {
              fileOutputStream.close()
          } catch (IOException e) {
              e.printStackTrace()
          }
          try {
              inputStream.close()
          } catch (IOException e) {
              e.printStackTrace()
          }
         }

         return cacheFile
    }

}