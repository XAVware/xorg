# xorg
## XAVware Organizer
I wrote this background process to help identify where my time is being spent on my laptop. I wanted to see statistics such my average time spent in XCode each week over the past 5 years, but Apple's built-in Screen Time only stores data for a week or two. There are third-party tools that accomplish this but I was skeptical about what else they are doing with the data. This lead me to opt for the DIY method.

Lightweight Obj-C stored locally in a SQLite database. Insights on your app usage without sacrificing your performance or your data. Enjoy.

---

## Features
- **Automatic Time Tracking**: Logs the time you spend in each macOS application.
- **Lightweight**: Runs in the background as a menu bar app with minimal memory usage (~18 MB).
- **Optional Notes**: Add a note of what you're working on, your future self will thank you.
- **Local Structured Data Storage**: Local SQLite database so you don't start getting ads for blue light glasses.

---
## Get Started

### 1. **Move Executable**
1. Click Product > Build in the XCode project
2. Locate the built app in the Products folder:

    ```bash
    cd ~/Library/Developer/Xcode/DerivedData && ls
    ```
    
3. Copy the directory name that corresponds to the app.
4. Move the app to the Applications folder. Replace `<DIRECTORY_NAME>` with the copied name:

    ```bash
        mv ~/Library/Developer/Xcode/DerivedData/<DIRECTORY_NAME>/Build/Products/Debug/xorg.app /Applications/
    ```
    
    Example:
    ```bash
        mv ~/Library/Developer/Xcode/DerivedData/xorg-ahiwxcdhqtwfevarmjfbbkfmjczb/Build/Products/Debug/xorg.app /Applications/
    ```

---

### 2. **Create the Launch Agent Plist File**
To start the app automatically at login, set up a Launch Agent:

1. Open Terminal and navigate to the `LaunchAgents` directory:

    ```bash
    cd ~/Library/LaunchAgents
    ```
2. Create a `.plist` file for the agent:

    ```bash
    touch com.xavware.xorg.plist
    ```
3. Open the file for editing:

    ```bash
    nano com.xavware.xorg.plist
    ```
4. Add the following content and save it (`Ctrl+O`, then `Ctrl+X` to exit):
    - If the app is not in `/Applications/`, replace `/Applications/xorg.app/Contents/MacOS/xorg` with the actual path to your app’s executable.

    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.xavware.xorg</string>
        <key>ProgramArguments</key>
        <array>
            <string>/Applications/xorg.app/Contents/MacOS/xorg</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
    </dict>
    </plist>
    ```

---

### 3. **Load the Launch Agent**
1. Use `launchctl` to load the agent:

    ```bash
    launchctl load ~/Library/LaunchAgents/com.xavware.xorg.plist
    ```
2. (Optional) Verify it is loaded:

    ```bash
    launchctl list | grep com.xavware.xorg
    ```

---

### 4. **Remove the App from Startup**
If you want to stop the app from starting automatically at login:

1. Unload the plist file:

    ```bash
    launchctl unload ~/Library/LaunchAgents/com.xavware.xorg.plist
    ```
2. Permanently delete the plist file:

    ```bash
    rm ~/Library/LaunchAgents/com.xavware.xorg.plist
    ```

---

## SQLite Schema
The app uses an SQLite database to store app usage data and reflections.

```sql
CREATE TABLE AppUsage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appName TEXT,
    startTime TEXT,
    endTime TEXT
);

CREATE TABLE Reflections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT,
    note TEXT
);





