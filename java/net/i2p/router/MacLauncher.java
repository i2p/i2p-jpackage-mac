package net.i2p.router;

import java.io.*;

public class MacLauncher {
    public static void main(String[] args) throws Exception {
        var here = new File(".");
        System.out.println("I'm in " + here.getAbsolutePath());
    }
}
