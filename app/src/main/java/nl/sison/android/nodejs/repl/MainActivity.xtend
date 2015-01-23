package nl.sison.android.nodejs.repl

import android.support.v7.app.ActionBarActivity
import android.support.v4.app.Fragment
import android.content.res.Configuration
import android.widget.ArrayAdapter
import android.os.Handler

import org.xtendroid.app.AndroidActivity
import org.xtendroid.annotations.AndroidFragment
import org.xtendroid.app.OnCreate
import nl.sison.android.nodejs.repl.NodeJNI

//import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStreamWriter;


@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
{
    val mHandler = new Handler()

    @BundleProperty
    String outFile

    @BundleProperty
    String inFile

    @OnCreate
    def init() {
        // read to TextView
        new Thread([
            var BufferedReader in = null
            try {
                in = new BufferedReader(new FileReader(outFile))
                while (in.ready())
                {
                    val str = in.readLine()
                    mHandler.post([
                        //textView.text = str
                    ])
                }
            }catch (FileNotFoundException e)
            {
                // meh
                e.printStackTrace()
            }catch (IOException e)
            {
                // meh
                e.printStackTrace()
            }
        ]).start()

        // write from EditText
        new Thread([
            var BufferedWriter out = null
            try {
                out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(inFile)))
                val content = "This content is written to..." + inFile
                out.write(content.toCharArray(), 0, content.toCharArray().length);
                out.flush()
                out.close()
            }catch (FileNotFoundException e)
            {
                // meh
                e.printStackTrace()
            }catch (IOException e)
            {
                // meh
                e.printStackTrace()
            }
        ]).start()
    }


}


@AndroidActivity(R.layout.activity_main_blacktoolbar) class MainActivity extends ActionBarActivity {

    String mOutfile
    String mInfile

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

       mOutfile = filesDir + '/out' // + something random
       mInfile  = filesDir + '/in'

       new Thread ([ NodeJNI.initStdio(mOutfile, mInfile) ]).start()
   }

   def setupFragment()
   {
        // TODO inject text instead of whole fragment
        val tx = supportFragmentManager.beginTransaction
        val frag = new ReplFragment()
        //frag.putOutfile(mOutfile).putInfile(mInfile)
        tx.replace(R.id.container, frag as Fragment).addToBackStack(null).commit();
   }

   MyActionBarDrawerToggle actionBarDrawerToggle

   def setupDrawerLayout()
   {
       val listView = drawerListView

       val String[] arrayOfWords = #["Hello", "Xtend"]
       listView.adapter = new ArrayAdapter<String>(this, R.layout.drawer_list_item, arrayOfWords)
//       listView.onItemClickListener = [parent, view, position, id|  ];

       val drawer = drawerLayout

       actionBarDrawerToggle = new MyActionBarDrawerToggle(this, drawer, toolbar)

       // This following line actually reveals the hamburger
       drawer.post([|actionBarDrawerToggle.syncState()]);

       drawer.drawerListener = actionBarDrawerToggle
   }

   def setupToolbar()
   {
        supportActionBar = toolbar
        val actionBar = supportActionBar
        actionBar.displayHomeAsUpEnabled = true
   }

   /*
   override setTitle(CharSequence title)
   {
       super.setTitle(title)
       actionBar.title = title
   }*/

   override onBackPressed() {
       val listView = drawerListView
       if (drawerLayout.isDrawerOpen(listView))
           drawerLayout.closeDrawer(listView)
       else
           super.onBackPressed()
   }

   /**
    * Invariant to changes in orientation
    */
   override onConfigurationChanged(Configuration newConfig) {
       super.onConfigurationChanged(newConfig);
       actionBarDrawerToggle.onConfigurationChanged(newConfig);
   }

}

