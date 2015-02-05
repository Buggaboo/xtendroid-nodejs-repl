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

import nl.sison.android.nodejs.repl.ReplFragment

import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import org.xtendroid.annotations.AddLogTag
import android.util.Log

import android.content.Context

import static extension gr.uoa.di.android.helpers.Net.*



/**
 * TODO add ip address on drawer
 */
@AddLogTag
@AndroidActivity(R.layout.activity_main_blacktoolbar) class MainActivity extends ActionBarActivity {

    ReplFragment fragment

    @OnCreate
    def init() {
        setupToolbar()
        setupDrawerLayout()
        setupFragment() // place a fragment already
    }

    def setupFragment()
    {
         // TODO inject text instead of whole fragment
         val tx = supportFragmentManager.beginTransaction
         fragment = new ReplFragment()
         tx.add(R.id.container, fragment as Fragment).commit()
    }
    
    MyActionBarDrawerToggle actionBarDrawerToggle
    
    def setupDrawerLayout()
    {
        val listView = drawerListView
    
        val String[] arrayOfWords = #["Hello", "Xtend"]
        listView.adapter = new ArrayAdapter<String>(this, R.layout.drawer_list_item, arrayOfWords)
    //    listView.onItemClickListener = [parent, view, position, id|  ]; // TODO add injectable examples
    
        val drawer = drawerLayout
    
        actionBarDrawerToggle = new MyActionBarDrawerToggle(this, drawer, toolbar)
    
        // This following line actually reveals the hamburger
        drawer.post([ actionBarDrawerToggle.syncState() ])
    
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
    
    override boolean onOptionsItemSelected(MenuItem item) {

        if (#[R.id.run, R.id.save, R.id.share, R.id.clear].contains(item.itemId))
        {
            if (fragment != null)
            {
                return fragment.onOptionsItemSelected(item)
            }
        }

        // TODO flesh out
        return super.onOptionsItemSelected(item)
    }
    
    /**
     * Invariant to changes in orientation
     */
    override onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig)
        actionBarDrawerToggle.onConfigurationChanged(newConfig)
    }
    
}

