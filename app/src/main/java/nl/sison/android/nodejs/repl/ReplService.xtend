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
import android.os.ParcelFileDescriptor

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

    LocalServerSocket serverSocket
    LocalSocket socket
/*
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
	override onCreate() {
		super.onCreate()
/*
        var file = new File(cacheDir + '/node-repl.sock')
        file.createNewFile
        var fo = new FileOutputStream(file);
        fo.write(0);
        fo.close();
        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.READ_AND_WRITE );
		serverSocket = new LocalServerSocket(pfd.fileDescriptor)

		Log.d(TAG, String.format("real file descriptor int: %d", pfd.fd))
*/

        // The lib is reloaded once, both scripts succesfully run
        new Thread ([
            NodeJNI.start(2, #["nodejs", createCacheFile("http_and_sock_repl.js").absolutePath ]) // runs succesfully
        ]).start()

        //serverSocket = new LocalServerSocket(createFileDescriptor(66))

	}

	/**
	 * Leverage reflection to call ZygoteInit#createFileDescriptor
	 */
	def createFileDescriptor(int fdi)
	{
        var cls = Class.forName('com.android.internal.os.ZygoteInit')
        for (m : cls.declaredMethods)
        {
            Log.d(TAG, m.toString)
        }
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

	override onDestroy() {
	    Log.d(TAG, "onDestroy")
	    closeSocket()
		super.onDestroy()
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

    OutputStream outputStream
    InputStream  inputStream

    val bufferSize = 512
    val buffer = newByteArrayOfSize(bufferSize)


    val baf = new ByteArrayBuffer(50);

    BufferedInputStream bis

    def setupLocalSocketStreams()
    {
        socket = serverSocket.accept() // blocks until connect

        Log.d(TAG, String.format("Attempting to connect with %s (unix local socket, ipc)", socket.localSocketAddress.name))
        Log.d(TAG, String.format("bound:%b\tconnected:%b", socket.bound, socket.connected))
        System.out.println('test' + socket.bound + socket.connected)

        outputStream = socket.outputStream
        inputStream  = socket.inputStream

        // test
        sendMessage('1 + 1')
    }

    def closeSocket()
    {
        socket.close()
        outputStream.close()
        inputStream.close()
        bis.close()
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