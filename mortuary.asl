/*  The Mortuary Assistant Autosplitter
    v0.0.10 --- By FailCake (edunad) & Hazzytje (Pointer wizard <3)

    GAME VERSIONS:
    - v1.0.33 = 45203456
    - v1.0.36 = 45207552

    CHANGELOG:
    - Game end enabled by default
    - Fixed hints
*/


state("The Mortuary Assistant", "1.0.36") { }

startup {

    // Settings
    settings.Add("modes", true, "Mode");
    settings.Add("mode_all_endings", false, "All Endings", "modes");
    settings.SetToolTip("mode_all_endings", "Timer starts after loading to the apartment and pauses on loadings");

    settings.Add("splitsgroup", true, "Splits");

    settings.Add("settingsgroup", true, "On..", "splitsgroup");
    settings.Add("split_sigil_found", false, "Sigil found", "settingsgroup");
    settings.SetToolTip("split_sigil_found", "When you uncover a sigil");
    settings.Add("split_body_complete", false, "Body complete", "settingsgroup");
    settings.SetToolTip("split_body_complete", "When you complete a body");
    settings.Add("autosplit_gameend", true, "Game end", "settingsgroup");
    settings.SetToolTip("autosplit_gameend", "When you burn a body");

    settings.Add("zonegroup", true, "Zone", "splitsgroup");
    settings.SetToolTip("zonegroup", "When you enter a certain zone");
    // settings.Add("zone_0", false, "Apartment", "zonegroup"); // not used
    settings.Add("zone_1", false, "Bathroom", "zonegroup");
    settings.Add("zone_2", false, "Hall", "zonegroup");
    settings.Add("zone_3", false, "Operation room", "zonegroup");
    settings.Add("zone_4", false, "Operation hall", "zonegroup");
    settings.Add("zone_5", false, "Cold Storage", "zonegroup");
    // settings.Add("zone_6", false, "Outside / Car", "zonegroup"); // not used
    // settings.Add("zone_7", false, "Car", "zonegroup"); // not used
    settings.Add("zone_8", false, "Basement", "zonegroup");

    settings.Add("itemgroup", true, "Items", "splitsgroup");
    settings.SetToolTip("itemgroup", "When you pickup a certain item");
    settings.Add("item_clipboard", false, "Clipboard", "itemgroup");
    settings.Add("item_notepad", false, "Notepad", "itemgroup");
    settings.Add("item_tablet", false, "Completed demon tablet", "itemgroup");

    settings.Add("itemlore", true, "Lore items", "splitsgroup");
    settings.SetToolTip("itemlore", "When you give a certain lore item");
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
    vars.inventoryBase = 0x00;

    if (vars.gameAssembly.ModuleMemorySize == 45207552) {
        vars.playerBase = 0x024CDE10;
        vars.gameManagerBase = 0x024A2D40;
        vars.staticDataBase = 0x024E1968;
        vars.inventoryBase = 0x024B72F8;
    } else {
        print("[WARNING] Invalid The Mortuary Assistant game version");
        print("[WARNING] Could not find pointers");
    }

    vars.gameBase = vars.gameAssembly.BaseAddress;
    vars.ptrPlayerOffset = vars.gameBase + vars.playerBase;
    vars.ptrGameManagerOffset = vars.gameBase + vars.gameManagerBase;
    vars.ptrStaticDatabaseOffset = vars.gameBase + vars.staticDataBase;
    vars.ptrInventoryOffset = vars.gameBase + vars.inventoryBase;

	vars.ingame = new MemoryWatcherList();
	vars.special = new MemoryWatcherList();

    Func<int, string> getItem = (index) => {
		IntPtr ptr;
        new DeepPointer(vars.ptrInventoryOffset, 0xB8, 0, 0x80, 0x10, 0x20 + 0x8 * index, 0x14).DerefOffsets(memory, out ptr);
        return memory.ReadString(ptr, 64);
	};
	vars.getItem = getItem;

    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x12D)) { Name = "gameEnded" });
    vars.ingame.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x58)) { Name = "sigils" });

    for (int i = 0; i < vars.__max_sigils; ++i)
        vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x48, 0x10, 0x20 + 0x8 * i, 0x28, 0x18)) { Name = "sigil_" + i });

    for (int i = 0; i < vars.__max_bodies; ++i)
        vars.ingame.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0xF8, 0x20 + 0x8 * i, 0x28)) { Name = "body_" + i });

    vars.ingame.Add(new MemoryWatcher<int>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x14C)) { Name = "zone" });
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x9D)) { Name = "hasTablet" }); // aka Mark
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA5)) { Name = "hasNotepad" });
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA7)) { Name = "hasClipboard" });

    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x9F)) { Name = "used10Year" }); // self coin
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA2)) { Name = "used5Year" }); // father coin
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA0)) { Name = "usedOtherCoin" }); // ??
    vars.ingame.Add(new MemoryWatcher<bool>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0xA4)) { Name = "usedNecklace" }); // necklace

    vars.special.Add(new MemoryWatcher<float>(new DeepPointer(vars.ptrStaticDatabaseOffset, 0xB8, 0, 0x18, 0x158)) { Name = "sessionTimer" });

    vars.__trackTablet = false;
    vars.__pickedCarKeys = false;
}

exit {
	timer.IsGameTimePaused = true; // Pause timer on game crash
}

isLoading {
    return settings["mode_all_endings"] && vars.special["sessionTimer"].Current <= 0f;
}

start {
    if(settings["mode_all_endings"]) {
        if(vars.special["sessionTimer"].Current == vars.special["sessionTimer"].Old) return false;
        return vars.special["sessionTimer"].Current > 0f && vars.special["sessionTimer"].Current <= 0.1f;
    } else {
        string item = vars.getItem(0);
        if(item == "itemCarKeys" && !vars.__pickedCarKeys) {
            vars.__pickedCarKeys = true;
        }else if(vars.__pickedCarKeys && item == null) {
            vars.__pickedCarKeys = false;
            return true;
        }

        return false;
    }
}

update {
    if(vars.ingame == null || vars.special == null) return;
    if(settings["mode_all_endings"]) vars.special.UpdateAll(game);

    if(timer.CurrentPhase != TimerPhase.Running) {
        vars.__zoneTrack = new bool[vars.__max_zones];
        vars.__trackTablet = false;
    } else {
        vars.ingame.UpdateAll(game);
    }
}

split {
    if(timer.CurrentPhase != TimerPhase.Running) return false;

    // Game over, split
    if(vars.ingame["gameEnded"].Current && vars.ingame["gameEnded"].Current != vars.ingame["gameEnded"].Old) return settings["autosplit_gameend"];

    // Clipboard, split
    if(vars.ingame["hasClipboard"].Current && vars.ingame["hasClipboard"].Current != vars.ingame["hasClipboard"].Old) return settings["item_clipboard"];

    // Notepad, split
    if(vars.ingame["hasNotepad"].Current && vars.ingame["hasNotepad"].Current != vars.ingame["hasNotepad"].Old) return settings["item_notepad"];

    // Demon Tablet, split
    if(!vars.__trackTablet && vars.ingame["hasTablet"].Current && vars.ingame["hasTablet"].Current != vars.ingame["hasTablet"].Old) {
        vars.__trackTablet = true;
        return settings["item_tablet"];
    }

    // 10 Year Coin
    if(vars.ingame["used10Year"].Current && vars.ingame["used10Year"].Current != vars.ingame["used10Year"].Old) return settings["item_10_coin"];
    if(vars.ingame["used5Year"].Current && vars.ingame["used5Year"].Current != vars.ingame["used5Year"].Old) return settings["item_5_coin"];
    if(vars.ingame["usedOtherCoin"].Current && vars.ingame["usedOtherCoin"].Current != vars.ingame["usedOtherCoin"].Old) return settings["item_coin"];
    if(vars.ingame["usedNecklace"].Current && vars.ingame["usedNecklace"].Current != vars.ingame["usedNecklace"].Old) return settings["item_necklace"];

    // Auto-split on body complete
    if(settings["split_body_complete"]) {
        for (int i = 0; i < vars.__max_bodies; ++i) {
            int oldState = vars.ingame["body_" + i].Old;
            int state = vars.ingame["body_" + i].Current;

            if(oldState == 5 && state == 0) { // TROCAR ---- > OPTABLE
                return true;
            }
        }
    }

    // Auto-split on sigil found
    if(settings["split_sigil_found"]) {
        for (int i = 0; i < vars.ingame["sigils"].Current; ++i) {
            bool oldState = vars.ingame["sigil_" + i].Old;
            bool state = vars.ingame["sigil_" + i].Current;
            if(oldState == state) continue;

            return true;
        }
    }

    // ZONE SPLITTING
    int currentZone = vars.ingame["zone"].Current;
    if(currentZone != vars.ingame["zone"].Old) {
        if(!vars.__zoneTrack[currentZone] && settings.ContainsKey("zone_" + currentZone)) {
            vars.__zoneTrack[currentZone] = true;
            return settings["zone_" + currentZone];
        }
    }

    return false;
}
