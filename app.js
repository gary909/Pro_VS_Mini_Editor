let midiOutput = null;
let originalMidiStatusText = "";

const ALL_CONTROLS = Array.from(document.querySelectorAll("input[data-cc]"));

const INIT_VALUES = {
    "mod-time": 0,
    "portamento-time": 0,
    "fx-engine": 0,
    "voice-a-wave": 0,
    "voice-b-wave": 0,
    "voice-c-wave": 0,
    "voice-d-wave": 0,
    "lfo2-amt": 0,
    "filter-env-amount": 0,
    "lfo1-wave": 0,
    "lfo2-wave": 0,
    "lfo1-amt": 0,
    "filter-resonance": 0,
    "lfo1-rate": 0,
    "lfo2-rate": 0,
    "filter-cutoff": 99,
    "amp-attack": 0,
    "amp-decay": 0,
    "amp-sustain": 99,
    "amp-release": 0,
    "filter-attack": 0,
    "filter-decay": 0,
    "filter-sustain": 99,
    "filter-release": 0,
    "chorus-depth": 0,
    "chorus-rate": 0,
    "voice-a-fine": 50,
    "voice-b-fine": 50,
    "voice-c-fine": 50,
    "voice-d-fine": 50,
    "voice-a-coarse": 50,
    "voice-b-coarse": 50,
    "voice-c-coarse": 50,
    "voice-d-coarse": 50
};

const WAVEFORM_BASE_PATH = "waveforms_svg_pass3/";
const WAVEFORM_INDEX = window.WAVEFORM_INDEX;
const WAVEFORM_BY_NUMBER = new Map(WAVEFORM_INDEX.map((entry) => [entry.n, entry]));
let activeWaveModalControlId = null;

function getWaveformEntry(value) {
    const numericValue = Number.isFinite(value) ? value : 0;
    const clampedValue = Math.max(0, Math.min(127, numericValue));
    return WAVEFORM_BY_NUMBER.get(clampedValue);
}

function getWaveCaption(entry) {
    const numberText = String(entry.n).padStart(3, "0");
    return `${numberText} - ${entry.name.toUpperCase()}`;
}

function updateWaveModalFromControl(control) {
    if (!control) {
        return;
    }

    const modal = document.getElementById("wave-modal");
    const modalImage = document.getElementById("wave-modal-image");
    const modalCaption = document.getElementById("wave-modal-caption");

    if (!modal || modal.classList.contains("modal-hidden") || !modalImage || !modalCaption) {
        return;
    }

    const entry = getWaveformEntry(parseInt(control.value, 10));
    modalImage.src = `${WAVEFORM_BASE_PATH}${entry.file}?t=${Date.now()}`;
    modalImage.alt = `Waveform ${entry.n} ${entry.name}`;
    modalCaption.textContent = getWaveCaption(entry);
}

function openWaveModal(controlId) {
    const control = document.getElementById(controlId);
    const modal = document.getElementById("wave-modal");
    if (!control || !modal) {
        return;
    }

    activeWaveModalControlId = controlId;
    modal.classList.remove("modal-hidden");
    modal.setAttribute("aria-hidden", "false");
    updateWaveModalFromControl(control);
}

function closeWaveModal() {
    const modal = document.getElementById("wave-modal");
    if (!modal) {
        return;
    }

    activeWaveModalControlId = null;
    modal.classList.add("modal-hidden");
    modal.setAttribute("aria-hidden", "true");
}

function setWavePreviewFromControl(control) {
    if (!control) {
        return;
    }

    updateWaveCycleIndicator(control);
    updateFxCycleIndicator(control);

    if (!control.dataset.wavePreview) {
        return;
    }

    const value = parseInt(control.value, 10);
    const entry = getWaveformEntry(value);
    const image = document.getElementById(control.dataset.wavePreview);

    if (image) {
        image.src = `${WAVEFORM_BASE_PATH}${entry.file}?t=${Date.now()}`;
        image.alt = `Waveform ${entry.n} ${entry.name}`;
    }

    if (control.dataset.waveCaption) {
        const caption = document.getElementById(control.dataset.waveCaption);
        if (caption) {
            caption.textContent = getWaveCaption(entry);
        }
    }

    if (activeWaveModalControlId && control.id === activeWaveModalControlId) {
        updateWaveModalFromControl(control);
    }
}

function syncAllWavePreviews() {
    ALL_CONTROLS.forEach((control) => {
        setWavePreviewFromControl(control);
    });
}

function getRandomInt(min, max) {
    const low = Math.ceil(min);
    const high = Math.floor(max);
    return Math.floor(Math.random() * (high - low + 1)) + low;
}

function getWaveName(value) {
    if (value <= 25) {
        return "TRIANGLE";
    }
    if (value <= 51) {
        return "S&H";
    }
    if (value <= 76) {
        return "RAMP";
    }
    if (value <= 102) {
        return "SAW";
    }
    return "SQUARE";
}

function getWaveIndexFromValue(value) {
    if (value <= 25) {
        return 0;
    }
    if (value <= 51) {
        return 1;
    }
    if (value <= 76) {
        return 2;
    }
    if (value <= 102) {
        return 3;
    }
    return 4;
}

function getWaveValueFromIndex(index) {
    const mappedValues = [0, 32, 64, 96, 127];
    return mappedValues[index] ?? 0;
}

function updateWaveCycleIndicator(control) {
    if (!control || control.dataset.format !== "wave3") {
        return;
    }

    const button = document.querySelector(`.wave-cycle-button[data-wave-cycle-for="${control.id}"]`);
    if (!button) {
        return;
    }

    const numericValue = parseInt(control.value, 10);
    const waveIndex = getWaveIndexFromValue(numericValue);
    const waveName = getWaveName(numericValue);
    const wrapper = button.closest(".wave-cycle-wrap");

    button.textContent = waveName.slice(0, 3);
    button.setAttribute("aria-label", `Cycle ${control.dataset.label || control.id} (current ${waveName})`);

    if (!wrapper) {
        return;
    }

    const options = wrapper.querySelectorAll(".wave-cycle-option");
    options.forEach((option, optionIndex) => {
        option.classList.toggle("is-active", optionIndex === waveIndex);
    });
}

function getFxIndexFromValue(value) {
    if (value <= 42) {
        return 0;
    }
    if (value <= 84) {
        return 1;
    }
    return 2;
}

function getFxValueFromIndex(index) {
    const mappedValues = [0, 64, 127];
    return mappedValues[index] ?? 0;
}

function updateFxCycleIndicator(control) {
    if (!control || control.dataset.format !== "fx3") {
        return;
    }

    const button = document.querySelector(`.wave-cycle-button[data-fx-cycle-for="${control.id}"]`);
    if (!button) {
        return;
    }

    const numericValue = parseInt(control.value, 10);
    const fxIndex = getFxIndexFromValue(numericValue);
    const fxName = getFxEngineName(numericValue);
    const wrapper = button.closest(".wave-cycle-wrap");

    button.textContent = fxName.slice(0, 3);
    button.setAttribute("aria-label", `Cycle ${control.dataset.label || control.id} (current ${fxName})`);

    if (!wrapper) {
        return;
    }

    const options = wrapper.querySelectorAll(".wave-cycle-option");
    options.forEach((option, optionIndex) => {
        option.classList.toggle("is-active", optionIndex === fxIndex);
    });
}

function getFxEngineName(value) {
    if (value <= 42) {
        return "CHORUS";
    }
    if (value <= 84) {
        return "ENSEMBLE";
    }
    return "REVERB";
}

function formatValue(control, value) {
    const format = control.dataset.format || "int";

    if (format === "wave3") {
        return getWaveName(value);
    }

    if (format === "fx3") {
        return getFxEngineName(value);
    }

    if (format === "signed50") {
        const centered = value - 50;
        if (centered > 0) {
            return `+${centered}`;
        }
        return `${centered}`;
    }

    return `${value}`;
}

function onMIDIFailure() {
    const status = document.getElementById("midi-device-status-text");
    if (status) {
        status.textContent = "ERROR: Could not access MIDI devices.";
        status.style.color = "#ff7f7f";
    }
}

function connectToSelectedOutput(portId, midiAccess) {
    midiOutput = portId ? midiAccess.outputs.get(portId) : null;
}

function populateOutputDevices(midiAccess) {
    const select = document.getElementById("midi-output-select");
    if (!select) {
        return;
    }

    const previousId = select.value;
    select.innerHTML = "";

    if (midiAccess.outputs.size === 0) {
        select.innerHTML = '<option value="">-- No Devices Found --</option>';
        midiOutput = null;
        return;
    }

    let autoSelectId = null;
    midiAccess.outputs.forEach((output) => {
        if (output.id === previousId) {
            autoSelectId = output.id;
        } else if (!autoSelectId && output.name && output.name.toLowerCase().includes("pro")) {
            autoSelectId = output.id;
        }
    });

    midiAccess.outputs.forEach((output) => {
        const option = document.createElement("option");
        option.value = output.id;
        option.textContent = output.name;
        if (output.id === autoSelectId) {
            option.selected = true;
        }
        select.appendChild(option);
    });

    if (!select.value && select.options.length > 0) {
        select.options[0].selected = true;
    }

    connectToSelectedOutput(select.value, midiAccess);
}

function sendMidiCC(cc, value) {
    if (!midiOutput) {
        return;
    }
    midiOutput.send([0xB0, cc, value]);
}

function updateTempStatus(text) {
    const select = document.getElementById("midi-output-select");
    if (!select || select.selectedIndex < 0) {
        return;
    }
    select.options[select.selectedIndex].textContent = text;
}

function restoreStatusText() {
    const select = document.getElementById("midi-output-select");
    if (!select || select.selectedIndex < 0) {
        return;
    }
    if (originalMidiStatusText) {
        select.options[select.selectedIndex].textContent = originalMidiStatusText;
    }
}

function attachControlListeners() {
    const select = document.getElementById("midi-output-select");

    ALL_CONTROLS.forEach((control) => {
        const cc = parseInt(control.dataset.cc, 10);
        const label = control.dataset.label || control.id.toUpperCase();

        control.addEventListener("mousedown", () => {
            if (!select || select.selectedIndex < 0) {
                return;
            }
            originalMidiStatusText = select.options[select.selectedIndex].textContent;
        });

        control.addEventListener(
            "touchstart",
            () => {
                if (!select || select.selectedIndex < 0) {
                    return;
                }
                originalMidiStatusText = select.options[select.selectedIndex].textContent;
            },
            { passive: true }
        );

        control.addEventListener("input", (event) => {
            const value = parseInt(event.target.value, 10);
            sendMidiCC(cc, value);
            const displayValue = formatValue(control, value);
            updateTempStatus(`${label}: ${displayValue}`);
            setWavePreviewFromControl(control);
        });

        // control.addEventListener("change", restoreStatusText);
        // control.addEventListener("mouseup", restoreStatusText);
        // control.addEventListener("touchend", restoreStatusText, { passive: true });
    });
}

function setupWaveCycleButtons() {
    const buttons = document.querySelectorAll(".wave-cycle-button[data-wave-cycle-for]");
    const select = document.getElementById("midi-output-select");

    buttons.forEach((button) => {
        const controlId = button.dataset.waveCycleFor;
        const control = document.getElementById(controlId);

        if (!control) {
            return;
        }

        updateWaveCycleIndicator(control);

        button.addEventListener("click", () => {
            if (select && select.selectedIndex >= 0) {
                originalMidiStatusText = select.options[select.selectedIndex].textContent;
            }

            const currentValue = parseInt(control.value, 10);
            const currentIndex = getWaveIndexFromValue(currentValue);
            const nextIndex = (currentIndex + 1) % 5;
            const nextValue = getWaveValueFromIndex(nextIndex);
            const cc = parseInt(control.dataset.cc, 10);
            const label = control.dataset.label || control.id.toUpperCase();

            control.value = nextValue;
            sendMidiCC(cc, nextValue);
            updateTempStatus(`${label}: ${formatValue(control, nextValue)}`);
            setWavePreviewFromControl(control);
            setTimeout(restoreStatusText, 900);
        });
    });
}

function setupFxCycleButtons() {
    const buttons = document.querySelectorAll(".wave-cycle-button[data-fx-cycle-for]");
    const select = document.getElementById("midi-output-select");

    buttons.forEach((button) => {
        const controlId = button.dataset.fxCycleFor;
        const control = document.getElementById(controlId);

        if (!control) {
            return;
        }

        updateFxCycleIndicator(control);

        button.addEventListener("click", () => {
            if (select && select.selectedIndex >= 0) {
                originalMidiStatusText = select.options[select.selectedIndex].textContent;
            }

            const currentValue = parseInt(control.value, 10);
            const currentIndex = getFxIndexFromValue(currentValue);
            const nextIndex = (currentIndex + 1) % 3;
            const nextValue = getFxValueFromIndex(nextIndex);
            const cc = parseInt(control.dataset.cc, 10);
            const label = control.dataset.label || control.id.toUpperCase();

            control.value = nextValue;
            sendMidiCC(cc, nextValue);
            updateTempStatus(`${label}: ${formatValue(control, nextValue)}`);
            setWavePreviewFromControl(control);
            setTimeout(restoreStatusText, 900);
        });
    });
}

function initPatch() {
    ALL_CONTROLS.forEach((control) => {
        const cc = parseInt(control.dataset.cc, 10);
        const fallbackValue = control.id.includes("sustain") ? parseInt(control.max, 10) : 0;
        const value = Object.prototype.hasOwnProperty.call(INIT_VALUES, control.id) ? INIT_VALUES[control.id] : fallbackValue;
        control.value = value;
        sendMidiCC(cc, value);
        setWavePreviewFromControl(control);
    });

    updateTempStatus("PATCH INITIALIZED");
    setTimeout(restoreStatusText, 900);
}

function randomPatch() {
    ALL_CONTROLS.forEach((control) => {
        const cc = parseInt(control.dataset.cc, 10);
        const min = parseInt(control.min || "0", 10);
        const max = parseInt(control.max || "127", 10);
        const randomValue = getRandomInt(min, max);
        control.value = randomValue;
        sendMidiCC(cc, randomValue);
        setWavePreviewFromControl(control);
    });

    updateTempStatus("RANDOM PATCH SENT");
    setTimeout(restoreStatusText, 900);
}

function onMIDISuccess(midiAccess) {
    populateOutputDevices(midiAccess);
    midiAccess.addEventListener("statechange", () => populateOutputDevices(midiAccess));

    const midiSelect = document.getElementById("midi-output-select");
    if (midiSelect) {
        midiSelect.addEventListener("change", (event) => {
            connectToSelectedOutput(event.target.value, midiAccess);
        });
    }

    const initButton = document.getElementById("init-patch-button");
    if (initButton) {
        initButton.addEventListener("click", initPatch);
    }

    const randomButton = document.getElementById("random-patch-button");
    if (randomButton) {
        randomButton.addEventListener("click", randomPatch);
    }
}

function openAboutModal() {
    const aboutModal = document.getElementById("about-modal");
    if (!aboutModal) {
        return;
    }
    aboutModal.classList.remove("modal-hidden");
    aboutModal.setAttribute("aria-hidden", "false");
}

function closeAboutModal() {
    const aboutModal = document.getElementById("about-modal");
    if (!aboutModal) {
        return;
    }
    aboutModal.classList.add("modal-hidden");
    aboutModal.setAttribute("aria-hidden", "true");
}

function setupNavAndModal() {
    const hamburger = document.getElementById("hamburger-menu");
    const sideNav = document.getElementById("side-nav");
    const closeBtn = document.getElementById("close-btn");
    const aboutBtn = document.getElementById("about-btn");
    const versionNumber = document.getElementById("version-number");
    const aboutModal = document.getElementById("about-modal");
    const aboutModalClose = document.getElementById("about-modal-close");
    const aboutModalContent = document.getElementById("about-modal-content");
    const waveModal = document.getElementById("wave-modal");
    const waveModalClose = document.getElementById("wave-modal-close");
    const waveModalContent = document.getElementById("wave-modal-content");
    const footerDisclaimer = document.getElementById("footer-disclaimer");
    const footerClose = document.getElementById("footer-disclaimer-close");

    if (hamburger && sideNav) {
        const openNav = () => {
            sideNav.style.width = "300px";
        };

        hamburger.addEventListener("click", openNav);
        hamburger.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                openNav();
            }
        });
    }

    if (closeBtn && sideNav) {
        closeBtn.addEventListener("click", (event) => {
            event.preventDefault();
            sideNav.style.width = "0";
        });
    }

    if (aboutBtn) {
        aboutBtn.addEventListener("click", (event) => {
            event.preventDefault();
            openAboutModal();
            if (sideNav) {
                sideNav.style.width = "0";
            }
        });
    }

    if (versionNumber) {
        versionNumber.addEventListener("click", openAboutModal);
    }

    if (aboutModalClose) {
        aboutModalClose.addEventListener("click", closeAboutModal);
    }

    if (aboutModal) {
        aboutModal.addEventListener("click", (event) => {
            if (!aboutModalContent || !aboutModalContent.contains(event.target)) {
                closeAboutModal();
            }
        });
    }

    if (waveModalClose) {
        waveModalClose.addEventListener("click", closeWaveModal);
    }

    if (waveModal) {
        waveModal.addEventListener("click", (event) => {
            if (!waveModalContent || !waveModalContent.contains(event.target)) {
                closeWaveModal();
            }
        });
    }

    if (footerDisclaimer && footerClose) {
        footerClose.addEventListener("click", () => {
            footerDisclaimer.style.display = "none";
        });
    }

    window.addEventListener("click", (event) => {
        if (
            sideNav &&
            hamburger &&
            event.target !== hamburger &&
            !hamburger.contains(event.target) &&
            event.target !== sideNav &&
            !sideNav.contains(event.target)
        ) {
            sideNav.style.width = "0";
        }
    });

    window.addEventListener("keydown", (event) => {
        if (event.key === "Escape") {
            closeAboutModal();
            closeWaveModal();
        }
    });

    const wavePreviewCards = document.querySelectorAll(".wave-preview[data-wave-control]");
    wavePreviewCards.forEach((card) => {
        const controlId = card.dataset.waveControl;
        card.addEventListener("click", () => {
            openWaveModal(controlId);
        });
        card.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                openWaveModal(controlId);
            }
        });
    });

    const accordions = document.getElementsByClassName("accordion-header");
    for (let i = 0; i < accordions.length; i += 1) {
        accordions[i].addEventListener("click", function onAccordionClick() {
            const panel = this.nextElementSibling;
            const isActive = this.classList.contains("active");

            for (let j = 0; j < accordions.length; j += 1) {
                accordions[j].classList.remove("active");
                accordions[j].nextElementSibling.style.maxHeight = null;
            }

            if (!isActive) {
                this.classList.add("active");
                panel.style.maxHeight = `${panel.scrollHeight}px`;
            }
        });
    }
}

syncAllWavePreviews();
setupWaveCycleButtons();
setupFxCycleButtons();
attachControlListeners();
setupNavAndModal();

if (navigator.requestMIDIAccess) {
    navigator.requestMIDIAccess().then(onMIDISuccess, onMIDIFailure);
} else {
    onMIDIFailure();
}
