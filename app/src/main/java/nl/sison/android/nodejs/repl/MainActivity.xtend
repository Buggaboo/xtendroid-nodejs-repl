package nl.sison.android.nodejs.repl

import android.support.v7.app.ActionBarActivity
import android.support.v4.app.Fragment
import android.content.res.Configuration
import android.widget.ArrayAdapter
import android.view.Menu
import android.view.MenuItem

import java.io.File

import org.xtendroid.app.AndroidActivity
import org.xtendroid.app.OnCreate
import nl.sison.android.nodejs.repl.NodeJNI

import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import org.xtendroid.annotations.AddLogTag
import android.util.Log

import android.content.Context

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream

import static extension gr.uoa.di.android.helpers.Net.*

import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.widget.EditText
import android.widget.TextView

import java.io.InputStream
import java.io.OutputStream

/**
 * TODO add ip address on drawer
 */
@AddLogTag
@AndroidActivity(R.layout.activity_main_blacktoolbar) class MainActivity extends ActionBarActivity {

    String mOutfile
    String mInfile

    File outfile
    File infile

    int inputHandle
    int outputHandle

    ReplFragment fragment

   @OnCreate
   def init() {
       setupToolbar()
       setupDrawerLayout()
       setupJni()
       setupFragment() // place a fragment already
   }

   def setupJni()
   {
       // TODO randomize, against distributed attacks
       if (!filesDir.exists())
       {
           filesDir.mkdir()
       }

       mOutfile = filesDir + '/out' // TODO filename + something random
       mInfile  = filesDir + '/in'

       infile  = new File (mInfile)
       outfile = new File (mOutfile)

       if (!infile.exists())
       {
           infile.createNewFile()
       }

       if (!outfile.exists())
       {
           outfile.createNewFile()
       }

       Log.d(TAG, String.format("ip addr: %s, %s", getIPAddress(false), getIPAddress(true)))
/*
       // remote http REPL
       new Thread ([
           NodeJNI.start(2, #["nodejs", createCacheFile("bbs.js").absolutePath])
       ]).start()
*/
       // local unix socket REPL
       new Thread([
           NodeJNI.start(2, #["nodejs", createCacheFile("repl_sock.js").absolutePath])
       ]).start()
   }

   override onResume()
   {
        super.onResume()
        var fileHandles = NodeJNI.redirectStdio(mOutfile, mInfile)
        inputHandle = fileHandles.get(0)
        outputHandle = fileHandles.get(1)
        Log.d(TAG, String.format("onResume: handles(in:%d, out:%d)", inputHandle, outputHandle))
   }

   override onPause()
   {
       super.onPause()
       Log.d(TAG, String.format("onPause: handles(in:%d, out:%d)", inputHandle, outputHandle))
       NodeJNI.stopRedirect(inputHandle, outputHandle)
   }

   def setupFragment()
   {
        // TODO inject text instead of whole fragment
        val tx = supportFragmentManager.beginTransaction
        fragment = new ReplFragment()
        fragment.putOutFile(mOutfile).putInFile(mInfile)
        tx.replace(R.id.container, fragment as Fragment).addToBackStack(null).commit()
   }

   MyActionBarDrawerToggle actionBarDrawerToggle

   def setupDrawerLayout()
   {
       val listView = drawerListView

       val String[] arrayOfWords = #["Hello", "Xtend"]
       listView.adapter = new ArrayAdapter<String>(this, R.layout.drawer_list_item, arrayOfWords)
//       listView.onItemClickListener = [parent, view, position, id|  ]; // TODO add injectable examples

       val drawer = drawerLayout

       actionBarDrawerToggle = new MyActionBarDrawerToggle(this, drawer, toolbar)

       // This following line actually reveals the hamburger
       drawer.post([|actionBarDrawerToggle.syncState()])

       drawer.drawerListener = actionBarDrawerToggle
   }

   override boolean onCreateOptionsMenu(Menu menu)
   {
       val inflater = menuInflater
       inflater.inflate(R.menu.main, menu)
       return super.onCreateOptionsMenu(menu)
   }

   def setupToolbar()
   {
        supportActionBar = toolbar
        val actionBar = supportActionBar
        actionBar.displayHomeAsUpEnabled = true
   }

   /**
    * TODO destroy Activity when no fragment is on the fragment stack
    */
   override onBackPressed() {
       val listView = drawerListView
       if (drawerLayout.isDrawerOpen(listView))
           drawerLayout.closeDrawer(listView)
       else
           super.onBackPressed()
   }

   // TODO add clear button
   override boolean onOptionsItemSelected(MenuItem item) {

       //System.in.read(fragment.editText.text.toString().bytes) // hopelessly broken
       val message = fragment.editText.text.toString()
       new Thread([
           startLocalClient("/data/data/nl.sison.android.nodejs.repl/cache/node-repl-sock", message, fragment.textView)
       ]).start()

       return super.onOptionsItemSelected(item)
   }

   /**
    * Invariant to changes in orientation
    */
   override onConfigurationChanged(Configuration newConfig) {
       super.onConfigurationChanged(newConfig)
       actionBarDrawerToggle.onConfigurationChanged(newConfig)
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

    /**
     *
     * Write to and read from unix socket (local unix socket repl)
     *
     * @param socketName
     * @param editText
     * @param textView
     * @throws Exception
     */
    def startLocalClient(String socketName, String message, TextView textView) throws Exception {
        // Construct a local socket
        val clientSocket = new LocalSocket();
        try {
            // Set the socket namespace
            val namespace = LocalSocketAddress.Namespace.FILESYSTEM;

            // Construct local socket address
            val address = new LocalSocketAddress(socketName, namespace);

            // Connect to local socket
            clientSocket.connect(address);

            // Get message as bytes
            val messageBytes = message.getBytes();

            // Send message bytes to the socket
            val outputStream = clientSocket.getOutputStream();
            outputStream.write(messageBytes);

            // Receive the message back from the socket
            val inputStream = clientSocket.getInputStream();
            val readSize = inputStream.read(messageBytes);

            // TODO append text
            runOnUiThread([ textView.setText(new String(messageBytes, 0, readSize)) ])

            // Close streams
            outputStream.close();
            inputStream.close();

        } finally {
            // Close the local socket
            clientSocket.close();
        }
    }

}

