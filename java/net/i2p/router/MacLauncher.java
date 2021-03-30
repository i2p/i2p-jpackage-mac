package net.i2p.router;

import java.io.*;
import java.util.*;

/**
 * Launches a router from a Mac App Bundle.  Uses Java 9 APIs.
 * Sets the following properties:
 * i2p.dir.base - this points to the (read-only) resources inside the bundle
 * mac.bundle.location - this points to the folder the bundle itself is located in.
 * router.pid - the pid of the java process.
 */
public class MacLauncher {

    /** this is totally undocumented */
    private static final String APP_PATH = "jpackage.app-path";

    public static void main(String[] args) throws Exception {
        String path = System.getProperty(APP_PATH,"unknown");
        File f = new File(path);
        File contents = f.getParentFile().getParentFile();
        File resources = new File(contents, "Resources");
        File bundleLocation = contents.getParentFile().getParentFile();

        System.setProperty("i2p.dir.base", resources.getAbsolutePath());
        System.setProperty("mac.bundle.location", bundleLocation.getAbsolutePath());
        System.setProperty("router.pid", String.valueOf(ProcessHandle.current().pid()));

        RouterLaunch.main(args);
    }
}
