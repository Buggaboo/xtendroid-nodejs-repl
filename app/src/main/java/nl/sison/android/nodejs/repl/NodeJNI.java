package nl.sison.android.nodejs.repl;

import android.content.Context;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Created by jasm on 1/22/15.
 */
public class NodeJNI {

    static {
        System.loadLibrary("iojs");
    }

    /**
     *
     * Use this in the main process to redirect all stdio
     *
     * @param inputFile
     * @param outputFile
     * @return file handles
     */
    public static native int[] redirectStdio(String inputFile, String outputFile);

    /**
     *
     * If we initialize and close in the same nodejs calling thread (e.g. open, do business, close)
     * then it will prematurely flush and close the streams,
     * Since we are running the libiojs from a spawned thread,
     * then the nodejs context will spawn a new one,
     * independent of the calling thread.
     *
     * @param inputHandle
     * @param outputHandle
     * @return
     */
    public static native int stopRedirect(int inputHandle, int outputHandle);

    public static native int start(int argc, String[] argv);

}