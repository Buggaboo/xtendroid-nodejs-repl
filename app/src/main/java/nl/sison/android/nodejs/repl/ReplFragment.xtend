package nl.sison.android.nodejs.repl

import android.support.v4.app.Fragment
import android.os.Handler
import android.widget.TextView

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
        textView.onFocusChangeListener = [v, hasFocus| readStdout() ]
        textView.onClickListener = [v| readStdout() ]
        editText.onFocusChangeListener = [v, hasFocus| readStdout() ]
        editText.onClickListener = [v| readStdout() ]
    }

    // read to TextView
    def readStdout()
    {
        new Thread([
            var BufferedReader in = null
            try {
                in = new BufferedReader(new FileReader(outFile))
                while (in.ready())
                {
                    val str = in.readLine()
                    mHandler.post([
                        textView.text = str
                    ])
                }
            }catch (FileNotFoundException e)
            {
                e.printStackTrace()
            }catch (IOException e)
            {
                e.printStackTrace()
            }
        ]).start()
    }

    // write from EditText
    def writeToStdin(String content)
    {
        new Thread([
            var BufferedWriter out = null
            try {
                out = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(inFile)))
                out.write(content.toCharArray(), 0, content.toCharArray().length);
                out.flush()
                out.close()
            }catch (FileNotFoundException e)
            {
                e.printStackTrace()
            }catch (IOException e)
            {
                e.printStackTrace()
            }
        ]).start()
    }


}