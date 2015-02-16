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
//import nl.sison.android.nodejs.repl.BuildConfig

import android.content.ServiceConnection
import android.content.ComponentName

import android.content.Intent

import android.content.Context

import android.os.IBinder

import android.view.Menu
import android.view.MenuItem

import java.io.InputStream

import java.io.OutputStream
import java.io.IOException

@AndroidParcelable
class StringParcel
{
    @Accessors
    String output
}

@AddLogTag
class HttpClientLoader extends BgSupportLoader<StringParcel>
{
    @Accessors
    String input

    new(Context context) {
        super(context)
        runInBg([ new StringParcel() ], [ Log.d(TAG, "auto destruct") ])
    }

}

@AddLogTag
@AndroidLoader
@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
    implements ServiceConnection, LoaderManager$LoaderCallbacks<StringParcel>
{
	HttpClientLoader httpReplClient = new HttpClientLoader(activity)

	override onLoadFinished(Loader loader, StringParcel parcel) {
	    Log.d(TAG, "onLoadFinished: " + parcel.output)
        textView.text = parcel.output
	}

	override onLoaderReset(Loader<StringParcel> loader) {
	}

    public new ()
    {
        arguments = new Bundle()
    }

    @OnCreate
    def init() {
        activity.startService(new Intent(activity, ReplService));
        doBindService()
//        if (BuildConfig.DEBUG)
        {
            LoaderManager.enableDebugLogging(true)
        }
    }

    override boolean onOptionsItemSelected(MenuItem item) {
//        if (#[R.id.run, R.id.save, R.id.share, R.id.clear].contains(item.itemId))
        if (R.id.run == item.itemId)
        {
/*
            val lm = activity.supportLoaderManager
            val input = editText.text.toString
            httpReplClientLoader.input = input
        	lm.restartLoader(LOADER_HTTP_REPL_CLIENT_ID, null, this);
        	Log.d(TAG, String.format("run: %s", input))
*/
            textView.text = new String(mService.sendMessage("1 + 1;"), 'UTF-8')
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
