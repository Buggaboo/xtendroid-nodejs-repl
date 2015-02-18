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
import nl.sison.android.nodejs.repl.BuildConfig

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

import android.widget.EditText
import android.widget.TextView

import android.os.Handler

@AndroidParcelable
class StringParcel
{
    @Accessors
    String output
}

/**
 * Experiment with Loaders
 */
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
//@AndroidLoader
@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
    implements ServiceConnection //, LoaderManager$LoaderCallbacks<StringParcel>
{
/*
	HttpClientLoader httpReplClient = new HttpClientLoader(activity)

	override onLoadFinished(Loader loader, StringParcel parcel) {
	    Log.d(TAG, "onLoadFinished: " + parcel.output)
	}

	override onLoaderReset(Loader<StringParcel> loader) {
	}
*/
    public new ()
    {
        arguments = new Bundle()
    }

    @OnCreate
    def init() {
        activity.startService(new Intent(activity, ReplService));
        // doBindService(ReplService) // for example
/*
        if (BuildConfig.DEBUG)
        {
            LoaderManager.enableDebugLogging(true)
        }
*/
        val textView = findViewById(R.id.textView) as Handler$Callback
        ReplWorker.create(activity.cacheDir + '/node-repl.sock', textView) // start if necessary
    }

    override boolean onOptionsItemSelected(MenuItem item) {
        if (R.id.run == item.itemId)
        {
            // @+id/meh magic breaks down for custom views
            val editText = findViewById(R.id.editText) as EditText
            ReplWorker.instance.write(editText.text.toString)
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

    /**
     * Usage: doBindService(ReplService)
     */
    def doBindService(Class<?> clazz) {
        activity.bindService(new Intent(activity, clazz), this, Context.BIND_AUTO_CREATE);
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
        super.onDestroy
        doUnbindService
        ReplWorker.instance.quit
    }
}
