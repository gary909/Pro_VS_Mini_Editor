let midiOutput = null;
let originalMidiStatusText = "";

const ALL_CONTROLS = Array.from(document.querySelectorAll("input[data-cc]"));

function getRandomInt(min, max) {
	const low = Math.ceil(min);
	const high = Math.floor(max);
	return Math.floor(Math.random() * (high - low + 1)) + low;
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

		control.addEventListener("touchstart", () => {
			if (!select || select.selectedIndex < 0) {
				return;
			}
			originalMidiStatusText = select.options[select.selectedIndex].textContent;
		}, { passive: true });

		control.addEventListener("input", (event) => {
			const value = parseInt(event.target.value, 10);
			sendMidiCC(cc, value);
			updateTempStatus(`${label}: ${value}`);
		});

		control.addEventListener("change", restoreStatusText);
		control.addEventListener("mouseup", restoreStatusText);
		control.addEventListener("touchend", restoreStatusText, { passive: true });
	});
}

function initPatch() {
	ALL_CONTROLS.forEach((control) => {
		const cc = parseInt(control.dataset.cc, 10);
		const defaultValue = control.id.includes("sustain") ? control.max : 0;
		control.value = defaultValue;
		sendMidiCC(cc, parseInt(defaultValue, 10));
	});
}

function randomPatch() {
	ALL_CONTROLS.forEach((control) => {
		const cc = parseInt(control.dataset.cc, 10);
		const min = parseInt(control.min || "0", 10);
		const max = parseInt(control.max || "127", 10);
		const randomValue = getRandomInt(min, max);
		control.value = randomValue;
		sendMidiCC(cc, randomValue);
	});
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
		}
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

attachControlListeners();
setupNavAndModal();

if (navigator.requestMIDIAccess) {
	navigator.requestMIDIAccess().then(onMIDISuccess, onMIDIFailure);
} else {
	onMIDIFailure();
}
