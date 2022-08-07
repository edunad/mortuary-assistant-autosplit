/*  The Mortuary Assistant Autosplitter
    v0.0.2 --- By FailCake (edunad) & Hazzytje (Pointer wizard <3)

    GAME VERSIONS:
    - v1.0.33 = 45203456

    CHANGELOG:
    - Add auto split on sigil found
*/


state("The Mortuary Assistant", "1.0.33") { }

startup {

    // Settings
    settings.Add("settingsgroup", true, "Auto-Split");
    settings.Add("split_sigil_found", false, "On sigil found", "settingsgroup");
    settings.Add("split_body_complete", false, "On body complete", "settingsgroup");
    settings.Add("autosplit_gameend", false, "On game end", "settingsgroup");


    // INTERNAL
    vars.__max_bodies = 3;
    vars.__max_sigils = 4;

    vars.__bodystate = new int[vars.__max_bodies];
    vars.__sigilTrack = new bool[vars.__max_sigils];
}

init {
    vars.playerBase = 0x00;
    vars.gameManagerBase = 0x00;

    vars.gameAssembly = modules.Where(m => m.ModuleName == "GameAssembly.dll").First();

    if(vars.gameAssembly.ModuleMemorySize == 45203456) {
        vars.playerBase = 0x024CCD40;
        vars.gameManagerBase = 0x024A1C70;
    }else {
        print("[WARNING] Invalid The Mortuary Assistant game version");
        print("[WARNING] Could not find scene pointers");
    }

    vars.gameBase = vars.gameAssembly.BaseAddress;
    vars.ptrPlayerOffset = vars.gameBase + vars.playerBase;
    vars.ptrGameManagerOffset = vars.gameBase + vars.gameManagerBase;

    Func<bool> isInCar = () => {
        if(vars.playerBase == 0x00) return false;

        IntPtr ptr;
        new DeepPointer(vars.ptrPlayerOffset, 0xB8, 0, 0x18, 0x178).DerefOffsets(memory, out ptr);
        return memory.ReadValue<bool>(ptr);
	};
	vars.isInCar = isInCar;

    Func<bool> gameEnded = () => {
        if(vars.gameManagerBase == 0x00) return false;

        IntPtr ptr;
        new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x125).DerefOffsets(memory, out ptr);
        return memory.ReadValue<bool>(ptr);
	};
	vars.gameEnded = gameEnded;

    Func<int> getSigilCount = () => {
        if(vars.gameManagerBase == 0x00) return -1;

        IntPtr ptr;
        new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x58).DerefOffsets(memory, out ptr);
        return memory.ReadValue<int>(ptr);
	};
	vars.getSigilCount = getSigilCount;


    Func<int, bool> isSigilVisible = (index) => {
        if(vars.gameManagerBase == 0x00) return false;

        IntPtr ptr;
        new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0x38, 0x30, 0x48, 0x10, 0x20 + 0x8 * index, 0x28, 0x18).DerefOffsets(memory, out ptr);
        return memory.ReadValue<bool>(ptr);
	};
	vars.isSigilVisible = isSigilVisible;

    /*
		0 = OPTABLE,
		1 = COLDSTORAGE,
		2 = INSPECTION,
		3 = Embalm,
		4 = NEUTRAL,
		5 = TROCAR
    */
    Func<int, int> getBodyState = (index) => {
        if(vars.gameManagerBase == 0x00) return -1;

        IntPtr ptr;
        new DeepPointer(vars.ptrGameManagerOffset, 0xB8, 0, 0xf0, 0x20 + 0x8 * index, 0x28).DerefOffsets(memory, out ptr);
        return memory.ReadValue<int>(ptr);
	};
	vars.getBodyState = getBodyState;

    old.__inCar = false;
}

start {
    if(old.__inCar == current.__inCar) return false;
    return current.__inCar;
}

update {
    if(vars.isInCar == null || vars.getSigilCount == null) return;

    current.__inCar = vars.isInCar();
    current.__sigils_spawned = vars.getSigilCount();

    if(timer.CurrentPhase != TimerPhase.Running) {
        vars.__bodystate = new int[vars.__max_bodies];
        vars.__sigilTrack = new bool[vars.__max_sigils];
    }
}

split {
    if(vars.gameEnded == null || vars.getBodyState == null) return false;
    if(timer.CurrentPhase != TimerPhase.Running) return false;

    // Game over, split everything
    if(settings["autosplit_gameend"] && vars.gameEnded()) return true;

    // Auto-split on body complete
    if(settings["split_body_complete"]) {
        for (int i = 0; i < vars.__max_bodies; ++i) {

            int oldState = vars.__bodystate[i];
            int state = vars.getBodyState(i);

            vars.__bodystate[i] = state;
            if(oldState == 5 && state == 0) { // TROCAR ---- > OPTABLE
                return true;
            }
        }
    }

    if(settings["split_sigil_found"]) {
        for (int i = 0; i < current.__sigils_spawned; ++i) {
            bool sigilVisible = vars.isSigilVisible(i);
            if(!sigilVisible || vars.__sigilTrack[i]) continue;

            vars.__sigilTrack[i] = true;
            return true;
        }
    }


    return false;
}