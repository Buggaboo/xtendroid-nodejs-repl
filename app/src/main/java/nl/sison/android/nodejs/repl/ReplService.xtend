package nl.sison.android.nodejs.repl

import nl.sison.android.nodejs.BuildConfig

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
import android.os.IBinder

import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.text.TextUtils
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.HandlerThread
import android.os.Bundle

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
        this.post[ ReplTextView.this.text = TextUtils.concat(ReplTextView.this.text, '\n', msg.data.getString(KEY_RESULT)) ]
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
    // TODO determine Xtend bug: no private ctors allowed, but I want a -ing Singleton.
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
        val MAX_ATTEMPTS = 100
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

        mInputStream  = mSocket.inputStream

        // urlConn.inputStream signals the outputStream is ready to be sent
        mBis = new BufferedInputStream(mInputStream) // socket in (receive)
    }

    /**
     * Utility method, used twice:
     * First used to send a message from the ui thread to the worker
     * then from the worker to the ui.
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
            var OutputStream out
            try {
                out = mSocket.outputStream // TODO test if necessary to run this on the ui thread
                out.write(TextUtils.concat(statement, '\n').toString.getBytes('UTF-8'))
                out.flush
            }catch (Throwable t)
            {
                mMainHandler.post([
                    Log.e(TAG, String.format("Failed to write to socket"))
                 ])
            }finally
            {
                if (out != null)
                {
                    out.close
                }
            }
        }

        var read = -1

        while ((read = mBis.read(buffer)) != -1)
        {
            mBaf.append(buffer, 0, read)
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
            mInputStream.close
            mBis.close
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

    /**
     * It's not actually necessary to bind with the service
     * just in case...
     */
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

		// TODO kickstart sensors with LocalServerSocket -- leave it to the Manifest
        // TODO redo this as a reloading the lib kills existing processes
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
     * Read from the assets and write to the cache
     */
    def File createCacheFile(String filename)
    {
         val cacheFile = new File(cacheDir, filename)

         // always load fresh files, unless deployed
         if (cacheFile.exists() && !BuildConfig.DEBUG) {
          return cacheFile
         }

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

    /**
     * Write string directly to a file
     */
    def File createCacheFile(String filename, String content)
    {
         val cacheFile = new File(cacheDir, filename)
         var FileOutputStream fileOutputStream = null

         try {
             fileOutputStream = new FileOutputStream(cacheFile)
             var bytes = content.getBytes('UTF-8')
             fileOutputStream.write(bytes, 0, bytes.length)
         } catch (IOException e) {
             e.printStackTrace()
         }finally {
             try {
                 fileOutputStream.close()
             } catch (IOException e) {
                 e.printStackTrace()
             }
         }

         return cacheFile
    }

}