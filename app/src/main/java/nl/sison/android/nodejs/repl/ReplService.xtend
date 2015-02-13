package nl.sison.android.nodejs.repl

import java.io.InputStream
import java.io.OutputStream

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException

import java.io.BufferedInputStream

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.util.Log
import android.widget.Toast
import android.os.IBinder

import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.text.TextUtils

import org.apache.http.util.ByteArrayBuffer

import nl.sison.android.nodejs.repl.NodeJNI

import org.xtendroid.annotations.AddLogTag

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

    var int[] handles
	override onCreate() {
		super.onCreate()

        // this redirect stuff blocks, and must be run on a different process altogether
        // I suspect that reloading the lib in the following thread destroys
        // this invocation's resulting state (i.e. stdio redirection)
        new Thread ([
            handles = NodeJNI.redirectStdio(cacheDir + '/io-in', cacheDir + '/io-out')
        ]).start()

        // The lib is reloaded once, both scripts succesfully run
        new Thread ([
            NodeJNI.start(2, #["nodejs", createCacheFile("bbs.js").absolutePath ]) // runs succesfully
            NodeJNI.start(2, #["nodejs", createCacheFile("repl_sock.js").absolutePath])
        ]).start()

//        Thread.sleep(5000) // no it is not a synchronization problem

//        startLocalSocket(cacheDir + '/node-repl-sock')
	}

	override int onStartCommand(Intent intent, int flags, int startId) {
		super.onStartCommand(intent, flags, startId)
		return START_STICKY
	}

	public def IsBoundable()
	{
	    return true // wtf is this supposed to do?
	}

	override onDestroy() {
	    Log.d(TAG, "onDestroy")
	    NodeJNI.stopRedirect(handles.get(0), handles.get(1))
	    closeSocket()
		super.onDestroy()
	}

    /**
     * The alternative way to enter code in nodejs/iojs
     */
    def File createCacheFile(String filename)
    {
         val cacheFile = new File(cacheDir, filename)

         if (cacheFile.exists()) {
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

    LocalSocket clientSocket
    OutputStream outputStream
    InputStream  inputStream

    val bufferSize = 512
    val buffer = newByteArrayOfSize(bufferSize)


    val baf = new ByteArrayBuffer(50);

    BufferedInputStream bis

    /**
     * TODO determine how to connect from the client
     */
    def startLocalSocket(String name)
    {
        Log.d(TAG, String.format("Attempting to connect with %s (unix local socket, ipc)", name))
        clientSocket = new LocalSocket()
        var namespace = LocalSocketAddress.Namespace.FILESYSTEM
        var address = new LocalSocketAddress(name, namespace)

        clientSocket.connect(address)

        outputStream = clientSocket.outputStream
        inputStream  = clientSocket.inputStream
    }

    def closeSocket()
    {
        outputStream.close()
        inputStream.close()
        clientSocket.close()
    }

    public def sendMessage(String message) {
        if (!TextUtils.isEmpty(message))
        {
            Log.d(TAG, "sending: " + message)
            outputStream.write(message.bytes)
            outputStream.flush
        }

        var read = -1
        var flag = true

        // urlConn.inputStream signals the outputStream is ready to be sent
        bis = new BufferedInputStream(inputStream) // socket in (receive)
        while(flag)
        {
            read = bis.read(buffer)
            if (read == -1) {
                flag = false // superhack since we don't have break/continue
            }else
            {
                baf.append(buffer, 0, read)
            }
        }

        Log.d(TAG, "receiving: " + new String(baf.toByteArray, 'UTF-8'))

        return baf.toByteArray
    }

}