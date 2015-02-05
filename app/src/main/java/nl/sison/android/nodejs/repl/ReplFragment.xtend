package nl.sison.android.nodejs.repl

import android.support.v4.app.Fragment
import android.os.Bundle
import android.support.v4.app.LoaderManager
import android.support.v4.content.Loader

import android.text.TextUtils

import org.xtendroid.annotations.AndroidLoader
import org.xtendroid.utils.BgSupportLoader
import org.xtendroid.annotations.AndroidFragment
import org.xtendroid.annotations.AddLogTag
import org.xtendroid.app.OnCreate
import org.xtendroid.parcel.AndroidParcelable


//import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import org.eclipse.xtend.lib.annotations.Accessors

import android.util.Log

import nl.sison.android.nodejs.repl.ReplService

import android.content.ServiceConnection
import android.content.ComponentName

import android.content.Intent

import android.content.Context

import android.os.IBinder

import android.view.Menu
import android.view.MenuItem

import java.io.InputStream

import java.io.OutputStream
import java.io.BufferedOutputStream
import java.io.BufferedInputStream
import java.net.HttpURLConnection
import java.net.URL

import java.net.ConnectException

import org.apache.http.util.ByteArrayBuffer

@Accessors
@AndroidParcelable
class StringParcel
{
    String output
}

@AddLogTag
class HttpClientLoader extends BgSupportLoader<StringParcel>
{
    @Accessors
    String input

    HttpURLConnection urlConn
    OutputStream outputStream

    URL url

    val bufferSize = 512
    val buffer = newByteArrayOfSize(bufferSize)

    val parcel = new StringParcel()

    val baf = new ByteArrayBuffer(50);

    BufferedInputStream bis

    new(Context context) {
        super(context)
        runInBg([ startLocalClient() ], [ urlConn.disconnect() ])
    }

    def startLocalClient()
    {
        // TODO implement retry and timeout
        if (url == null)
        {
            var retry = true
            while (retry)
            {
                try {
                    url = new URL("http://localhost:8000")

                    urlConn = url.openConnection() as HttpURLConnection
                    urlConn.doOutput = true
                    urlConn.doInput = true
                    urlConn.chunkedStreamingMode = 0
                    urlConn.requestMethod = "PUT"
                    urlConn.setRequestProperty("Content-Type", "multipart/octet-stream")
                    urlConn.setRequestProperty("Accept", "*/*")
                    urlConn.setRequestProperty("Expect", "100-continue")
                    urlConn.setRequestProperty("Transfer-Encoding", "chunked")
                    urlConn.allowUserInteraction = false
                    urlConn.connect()

                    outputStream = new BufferedOutputStream(urlConn.outputStream) // socket out (send)
                    bis = new BufferedInputStream(urlConn.inputStream) // socket in (receive)

                    retry = false

                }catch(ConnectException ce) {
                    Log.d(TAG, "retry connection")
                    Thread.sleep(2000)
                }
            }
        }

        parcel.output = new String(sendMessage(input), "UTF-8")

        return parcel
    }


    def sendMessage(String message) {
        if (!TextUtils.isEmpty(message))
        {
            outputStream.write(message.bytes)
            outputStream.flush
        }
        var read = -1
        var flag = true
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
        return baf.toByteArray
    }

}

@AddLogTag
@AndroidLoader
@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
    implements ServiceConnection, LoaderManager$LoaderCallbacks<StringParcel>
{
	HttpClientLoader loader = new HttpClientLoader(activity)

	override onLoadFinished(Loader loader, StringParcel parcel) {
	    Log.d(TAG, parcel.output)
        textView.text = parcel.output
	}

	override onLoaderReset(Loader loader) {
	}

    public new ()
    {
        arguments = new Bundle()
    }

    @OnCreate
    def init() {
        activity.startService(new Intent(activity, ReplService));
        doBindService()
    }

    override boolean onOptionsItemSelected(MenuItem item) {

//        if (#[R.id.run, R.id.save, R.id.share, R.id.clear].contains(item.itemId))
        if (R.id.run == item.itemId)
        {

        }
        return super.onOptionsItemSelected(item)
    }


    ReplService mService

    override onServiceConnected(ComponentName name, IBinder binder)
    {
         mService = (binder as ReplService$ReplBinder).service
    }

    override onServiceDisconnected(ComponentName name)
    {
        mService = null
    }

    var boolean mIsBound = false

    def doBindService() {
        activity.bindService(new Intent(activity, ReplService), this, Context.BIND_AUTO_CREATE);
        mIsBound = true;
        if(mService != null) {
            mService.IsBoundable();
        }
    }

    // Detach our existing connection.
    def doUnbindService() {
        if (mIsBound) {
            activity.unbindService(this);
            mIsBound = false;
        }
    }

    override onDestroy()
    {
        super.onDestroy()
        doUnbindService();
    }
}