package net.i2p.router;

import java.io.*;
import java.util.*;

public class MacLauncher {
    /** this is totally undocumented */
    private static final String APP_PATH = "jpackage.app-path";

    public static void main(String[] args) throws Exception {
        String path = System.getProperty(APP_PATH,"unknown");
        File f = new File(path);
        File contents = f.getParentFile().getParentFile();
        File resources = new File(contents, "Resources");

        System.setProperty("i2p.dir.base", resources.getAbsolutePath());
        RouterLaunch.main(args);
    }
}
