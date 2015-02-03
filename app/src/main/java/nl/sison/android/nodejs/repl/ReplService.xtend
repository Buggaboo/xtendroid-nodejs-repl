package nl.sison.android.nodejs.repl

import java.io.BufferedWriter
import java.io.OutputStreamWriter
import java.io.PrintWriter

import java.io.InputStream
import java.io.OutputStream

import java.io.BufferedOutputStream
import java.io.BufferedInputStream
import java.net.HttpURLConnection
import java.net.URL

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import android.widget.Toast
import android.os.IBinder

import nl.sison.android.nodejs.repl.NodeJNI

import org.xtendroid.annotations.AddLogTag

@AddLogTag
class ReplService extends Service {

    HttpURLConnection urlConn

    OutputStream outputStream
    InputStream  inputStream

	PrintWriter out

	override onBind(Intent intent) {
		return myBinder
	}

	val private IBinder myBinder = new LocalBinder(this)

	static class LocalBinder extends Binder {

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
	}

	def IsBoundable() {

	}

	public def sendMessage(String message) {
	   // TODO do something with printwriter...
	}

	override int onStartCommand(Intent intent, int flags, int startId) {
		super.onStartCommand(intent, flags, startId)

        // remote http REPL
        NodeJNI.start(2, #["nodejs", createCacheFile("bbs.js").absolutePath])

		return START_STICKY
	}

	override onDestroy() {
		super.onDestroy()

	}

    def startLocalClient()
    {
        val url = new URL("http://localhost:8000")

        urlConn = url.openConnection() as HttpURLConnection
        urlConn.doOutput = true
        urlConn.doInput = true
        urlConn.chunkedStreamingMode = 0
        urlConn.requestMethod = "PUT"
        //urlConn.setRequestProperty("Content-Type", "multipart/octet-stream")
        urlConn.setRequestProperty("Accept", "*/*")
        urlConn.setRequestProperty("Expect", "100-continue")
        urlConn.setRequestProperty("Transfer-Encoding", "chunked")
        urlConn.connect()
        outputStream = new BufferedOutputStream(urlConn.outputStream) // socket out (send)
        inputStream = new BufferedInputStream(urlConn.inputStream) // socket in (receive)

        val bufferSize = 1024
        val buffer = newByteArrayOfSize(bufferSize)

        val readSize = inputStream.read(buffer);
/*
    mHandler.post([
             Log.d(TAG, String.format("socket: %s", new String(buffer, 0, readSize)))
             ])
*/

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

}