package net.i2p.router;

import java.io.*;
import java.nio.file.*;

/**
 * Manages the LaunchAgent for auto-starting I2P at login on macOS.
 *
 * The LaunchAgent plist is bundled in the app at:
 *   I2P.app/Contents/Resources/LaunchAgents/net.i2p.router.plist
 *
 * When enabled, it is copied to:
 *   ~/Library/LaunchAgents/net.i2p.router.plist
 *
 * Usage from Router Console or other I2P code:
 *   MacAutoStart.isEnabled()     - check if auto-start is enabled
 *   MacAutoStart.enable()        - enable auto-start at login
 *   MacAutoStart.disable()       - disable auto-start at login
 */
public class MacAutoStart {

    private static final String PLIST_NAME = "net.i2p.router.plist";
    private static final String LAUNCH_AGENTS_DIR = "Library/LaunchAgents";

    /**
     * Check if auto-start at login is currently enabled.
     *
     * @return true if the LaunchAgent is installed
     */
    public static boolean isEnabled() {
        Path dest = getDestinationPath();
        return Files.exists(dest);
    }

    /**
     * Enable auto-start at login by installing the LaunchAgent.
     *
     * @return true if successfully enabled
     * @throws IOException if the plist cannot be copied
     */
    public static boolean enable() throws IOException {
        Path source = getSourcePath();
        Path dest = getDestinationPath();

        if (!Files.exists(source)) {
            throw new IOException("LaunchAgent plist not found in app bundle: " + source);
        }

        // Create ~/Library/LaunchAgents if it doesn't exist
        Path destDir = dest.getParent();
        if (!Files.exists(destDir)) {
            Files.createDirectories(destDir);
        }

        // Copy the plist
        Files.copy(source, dest, StandardCopyOption.REPLACE_EXISTING);

        // Load it immediately (so it takes effect without logout)
        try {
            ProcessBuilder pb = new ProcessBuilder("launchctl", "load", dest.toString());
            pb.inheritIO();
            Process p = pb.start();
            p.waitFor();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        return true;
    }

    /**
     * Disable auto-start at login by removing the LaunchAgent.
     *
     * @return true if successfully disabled (or was already disabled)
     * @throws IOException if the plist cannot be removed
     */
    public static boolean disable() throws IOException {
        Path dest = getDestinationPath();

        if (!Files.exists(dest)) {
            return true; // Already disabled
        }

        // Unload it first
        try {
            ProcessBuilder pb = new ProcessBuilder("launchctl", "unload", dest.toString());
            pb.inheritIO();
            Process p = pb.start();
            p.waitFor();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // Remove the plist
        Files.deleteIfExists(dest);
        return true;
    }

    /**
     * Get the path to the bundled LaunchAgent plist.
     */
    private static Path getSourcePath() {
        // The app path is set by jpackage
        String appPath = System.getProperty("jpackage.app-path", "unknown");
        if ("unknown".equals(appPath)) {
            // Fallback: assume standard installation location
            return Paths.get("/Applications/I2P.app/Contents/Resources/LaunchAgents", PLIST_NAME);
        }

        // appPath points to I2P.app/Contents/MacOS/I2P
        // We need I2P.app/Contents/Resources/LaunchAgents/
        File appFile = new File(appPath);
        File contents = appFile.getParentFile().getParentFile();
        return new File(contents, "Resources/LaunchAgents/" + PLIST_NAME).toPath();
    }

    /**
     * Get the path where the LaunchAgent should be installed.
     */
    private static Path getDestinationPath() {
        String home = System.getProperty("user.home");
        return Paths.get(home, LAUNCH_AGENTS_DIR, PLIST_NAME);
    }

    /**
     * Check if we're running on macOS.
     */
    public static boolean isMacOS() {
        String os = System.getProperty("os.name", "").toLowerCase();
        return os.contains("mac") || os.contains("darwin");
    }
}
