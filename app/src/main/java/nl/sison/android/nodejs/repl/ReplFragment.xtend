package nl.sison.android.nodejs.repl

import android.support.v4.app.Fragment
import android.os.Bundle

import org.xtendroid.annotations.AndroidFragment
import org.xtendroid.annotations.AddLogTag
import org.xtendroid.app.OnCreate

//import static extension org.xtendroid.utils.AlertUtils.*
import static extension nl.sison.android.nodejs.repl.Settings.*
import org.xtendroid.annotations.BundleProperty

import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.FileReader
import java.io.IOException
import java.io.OutputStreamWriter

import android.util.Log

@AddLogTag
@AndroidFragment(R.layout.fragment_repl) class ReplFragment extends Fragment
{
    public new ()
    {
        arguments = new Bundle()
    }
}