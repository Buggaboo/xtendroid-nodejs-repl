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

/**
 * TODO add ip address on drawer
 */
@AndroidActivity(R.layout.activity_main_blacktoolbar) class MainActivity extends ActionBarActivity {

    String mOutfile
    String mInfile

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

       val infile  = new File (mInfile)
       val outfile = new File (mOutfile)

       if (!infile.exists())
       {
           infile.createNewFile()
       }

       if (!outfile.exists())
       {
           outfile.createNewFile()
       }

       val doesNothingWhatsoever = 0
       new Thread
       ([
           NodeJNI.initStdio(mOutfile, mInfile)
           NodeJNI.start(doesNothingWhatsoever, #["will_this_be_ignored"])
       ]).start()
   }

   def setupFragment()
   {
        // TODO inject text instead of whole fragment
        val tx = supportFragmentManager.beginTransaction
        fragment = new ReplFragment()
        fragment.putOutFile(mOutfile).putInFile(mInfile)
        tx.replace(R.id.container, fragment as Fragment).addToBackStack(null).commit();
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
       drawer.post([|actionBarDrawerToggle.syncState()]);

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

   override onBackPressed() {
       val listView = drawerListView
       if (drawerLayout.isDrawerOpen(listView))
           drawerLayout.closeDrawer(listView)
       else
           super.onBackPressed()
   }

   override boolean onOptionsItemSelected(MenuItem item) {
       // TODO add clear button
       fragment.writeToStdin(fragment.editText.text.toString())
       fragment.readStdout()
       toast(fragment.editText.text.toString())

       return super.onOptionsItemSelected(item)
   }

   /**
    * Invariant to changes in orientation
    */
   override onConfigurationChanged(Configuration newConfig) {
       super.onConfigurationChanged(newConfig);
       actionBarDrawerToggle.onConfigurationChanged(newConfig);
   }

}

