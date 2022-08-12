/*  The Mortuary Assistant Autosplitter
    v0.0.6 --- By FailCake (edunad) & Hazzytje (Pointer wizard <3)

    GAME VERSIONS:
    - v1.0.33 = 45203456
    - v1.0.36 = 45207552

    CHANGELOG:
    - Fix pointers not working on new update (v1.0.36)
*/


state("The Mortuary Assistant", "1.0.36") { }

startup {

    // Settings
    settings.Add("settingsgroup", true, "Auto-split on..");
    settings.Add("split_sigil_found", false, "Sigil found", "settingsgroup");
    settings.Add("split_body_complete", false, "Body complete", "settingsgroup");
    settings.Add("autosplit_gameend", false, "Game end", "settingsgroup");

    settings.Add("zonegroup", true, "Auto-split zone");
    // settings.Add("zone_0", false, "Apartment", "zonegroup"); // not used
    settings.Add("zone_1", false, "Bathroom", "zonegroup");
    settings.Add("zone_2", false, "Hall", "zonegroup");
    settings.Add("zone_3", false, "Operation room", "zonegroup");
    settings.Add("zone_4", false, "Operation hall", "zonegroup");
    settings.Add("zone_5", false, "Cold Storage", "zonegroup");
    // settings.Add("zone_6", false, "Outside / Car", "zonegroup"); // not used
    // settings.Add("zone_7", false, "Car", "zonegroup"); // not used
    settings.Add("zone_8", false, "Basement", "zonegroup");

    settings.Add("itemgroup", true, "Auto-split items");
    settings.Add("item_clipboard", false, "Clipboard", "itemgroup");
    settings.Add("item_notepad", false, "Notepad", "itemgroup");
    settings.Add("item_tablet", false, "Completed demon tablet", "itemgroup");

    settings.Add("itemlore", true, "Auto-split lore items");
    settings.Add("item_10_coin", false, "Used Ten Year Coin", "itemlore");
    settings.Add("item_5_coin", false, "Used Five Year Coin (dad)", "itemlore");
    settings.Add("item_coin", false, "Used Other coin", "itemlore");
    settings.Add("item_necklace", false, "Used Necklace", "itemlore");

    // INTERNAL
    vars.__max_bodies = 3;
    vars.__max_sigils = 4;
    vars.__max_zones = 9;

    vars.__zoneTrack = new bool[vars.__max_zones];
    // ---
}


init {
    if(modules == null) return;

    vars.gameAssembly = modules.Where(m => m.ModuleName == "GameAssembly.dll").First();
    if(vars.gameAssembly == null) return;

    vars.gameBase = vars.gameAssembly.BaseAddress;

    vars.playerBase = 0x00;
    vars.gameManagerBase = 0x00;
    vars.staticDataBase = 0x00;

    if (vars.gameAssembly.ModuleMemorySize == 45207552) {
        vars.playerBase = 0x024CDE10;
        vars.gameManagerBase = 0x024A2D40;
        vars.staticDataBase = 0x024E1968;
    } else {
        print("[WARNING] Invalid The Mortuary Assistant game version");
        print("[WARNING] Could not find pointers");
    }

    vars.gameBase = vars.gameAssembly.BaseAddress;
    vars.ptrPlayerOffset = vars.gameBase + vars.playerBase;
    vars.ptrGameManagerOffset = vars.gameBase + vars.gameManagerBase;
    vars.ptrStaticDatabaseOffset = vars.gameBase + vars.staticDataBase;

	vars.startup = new MemoryWatcherList();
	vars.watchers = new MemoryWatcherList();

    vars.startup.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrPlayerOffset, 0xB8, 0, 0x18, 0x178)) { Name = "inCar" });

    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x12D)) { Name = "gameEnded" });
    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x58)) { Name = "sigils" });

    for (int i = 0; i < vars.__max_sigils; ++i)
        vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x48, 0x10, 0x20 + 0x8 * i, 0x28, 0x18)) { Name = "sigil_" + i });

    for (int i = 0; i < vars.__max_bodies; ++i)
        vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0xF8, 0x20 + 0x8 * i, 0x28)) { Name = "body_" + i });


    vars.watchers.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x14C)) { Name = "zone" });
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x9D)) { Name = "hasTablet" }); // aka Mark
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA5)) { Name = "hasNotepad" });
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA7)) { Name = "hasClipboard" });

    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x9F)) { Name = "used10Year" }); // self coin
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA2)) { Name = "used5Year" }); // father coin
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA0)) { Name = "usedOtherCoin" }); // ??
    vars.watchers.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA4)) { Name = "usedNecklace" }); // necklace

    vars.__trackTablet = false;
}

start {
    if(vars.startup["inCar"].Current == vars.startup["inCar"].Old) return false;
    return vars.startup["inCar"].Current;
}

update {
    if(vars.startup == null || vars.watchers == null) return;

    if(timer.CurrentPhase != TimerPhase.Running) {
        vars.__zoneTrack = new bool[vars.__max_zones];
        vars.__trackTablet = false;

        vars.startup.UpdateAll(game);
    } else {
        vars.watchers.UpdateAll(game);
    }
}

split {
    if(timer.CurrentPhase != TimerPhase.Running) return false;

    // Game over, split
    if(vars.watchers["gameEnded"].Current != vars.watchers["gameEnded"].Old) return settings["autosplit_gameend"];

    // Clipboard, split
    if(vars.watchers["hasClipboard"].Current != vars.watchers["hasClipboard"].Old) return settings["item_clipboard"];

    // Notepad, split
    if(vars.watchers["hasNotepad"].Current != vars.watchers["hasNotepad"].Old) return settings["item_notepad"];

    // Demon Tablet, split
    if(!vars.__trackTablet && vars.watchers["hasTablet"].Current != vars.watchers["hasTablet"].Old){
        vars.__trackTablet = true;
        return settings["item_tablet"];
    }

    // 10 Year Coin
    if(vars.watchers["used10Year"].Current != vars.watchers["used10Year"].Old) return settings["item_10_coin"];
    if(vars.watchers["used5Year"].Current != vars.watchers["used5Year"].Old) return settings["item_5_coin"];
    if(vars.watchers["usedOtherCoin"].Current != vars.watchers["usedOtherCoin"].Old) return settings["item_coin"];
    if(vars.watchers["usedNecklace"].Current != vars.watchers["usedNecklace"].Old) return settings["item_necklace"];

    // Auto-split on body complete
    if(settings["split_body_complete"]) {
        for (int i = 0; i < vars.__max_bodies; ++i) {
            int oldState = vars.watchers["body_" + i].Old;
            int state = vars.watchers["body_" + i].Current;

            if(oldState == 5 && state == 0) { // TROCAR ---- > OPTABLE
                return true;
            }
        }
    }

    // Auto-split on sigil found
    if(settings["split_sigil_found"]) {
        for (int i = 0; i < vars.watchers["sigils"].Current; ++i) {
            bool oldState = vars.watchers["sigil_" + i].Old;
            bool state = vars.watchers["sigil_" + i].Current;
            if(oldState == state) continue;

            return true;
        }
    }

    // ZONE SPLITTING
    int currentZone = vars.watchers["zone"].Current;
    if(currentZone != vars.watchers["zone"].Old) {
        if(!vars.__zoneTrack[currentZone] && settings.ContainsKey("zone_" + currentZone)) {
            vars.__zoneTrack[currentZone] = true;
            return settings["zone_" + currentZone];
        }
    }

    return false;
}
