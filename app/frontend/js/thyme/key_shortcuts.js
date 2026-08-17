// Configuration for the search popup shortcut to make it easy to change
export const SEARCH_SHORTCUT = {
  key: "s",
  shiftKey: true,
  ctrlKey: false,
  metaKey: false,
};

/**
 * Adds general shortcuts for the thyme player.
 */
export function addGeneralShortcuts() {
  const video = document.getElementById("video");

  const handler = function (evt) {
    if (thymeAttributes.lockKeyListeners) {
      return;
    }
    const key = evt.key;
    if (key === " ") {
      if (video.paused) {
        video.play();
      }
      else {
        video.pause();
      }
    }
    else if (key === "ArrowRight") {
      $("#plus-ten").trigger("click");
    }
    else if (key === "ArrowLeft") {
      $("#minus-ten").trigger("click");
    }
    else if (key === "f") {
      $("#full-screen").trigger("click");
    }
    else if (key === "m") {
      $("#mute").trigger("click");
    }
    else if (key === "PageUp") {
      video.volume = Math.min(video.volume + 0.1, 1);
    }
    else if (key === "PageDown") {
      video.volume = Math.max(video.volume - 0.1, 0);
    }
  };

  window.addEventListener("keydown", handler);
  return handler;
}

export function removeGeneralShortcuts(handler) {
  window.removeEventListener("keydown", handler);
}

/**
 * Adds Thyme-player specific shortcuts.
 */
export function addPlayerShortcuts() {
  const handler = function (evt) {
    if (thymeAttributes.lockKeyListeners) {
      return;
    }
    const key = evt.key;
    if (key === "i") {
      $("#ia-active").trigger("click");
    }
    else if (key === "ArrowUp") {
      $("#next-chapter").trigger("click");
    }
    else if (key === "ArrowDown") {
      $("#previous-chapter").trigger("click");
    }

    // annotation-related shortcuts
    if (thymeAttributes.disableAnnotationKeyListeners) {
      return;
    }
    else if (key === "a") {
      $("#annotation-previous-button").trigger("click");
    }
    else if (key === "s") {
      $("#annotation-goto-button").trigger("click");
    }
    else if (key === "d") {
      $("#annotation-next-button").trigger("click");
    }
  };

  window.addEventListener("keydown", handler);
  return handler;
}

export function removePlayerShortcuts(handler) {
  window.removeEventListener("keydown", handler);
}

/**
 * Adds Thyme feedback specific shortcuts.
 */
export function addFeedbackShortcuts() {
  const handler = function (evt) {
    if (thymeAttributes.lockKeyListeners || thymeAttributes.disableAnnotationKeyListeners) {
      return;
    }
    const key = evt.key;
    if (key === "q") {
      $("#annotation-category-mistake-switch").trigger("click");
    }
    else if (key === "w") {
      $("#annotation-category-content-switch").trigger("click");
    }
    else if (key === "e") {
      $("#annotation-category-presentation-switch").trigger("click");
    }
    else if (key === "r") {
      $("#annotation-category-note-switch").trigger("click");
    }
    else if (key === "a") {
      $("#annotation-previous-button").trigger("click");
    }
    else if (key === "s") {
      $("#annotation-goto-button").trigger("click");
    }
    else if (key === "d") {
      $("#annotation-next-button").trigger("click");
    }
  };

  window.addEventListener("keydown", handler);
  return handler;
}

export function removeFeedbackShortcuts(handler) {
  window.removeEventListener("keydown", handler);
}

/**
 * Adds shortcuts for the search popup component.
 */
export function addSearchShortcuts(searchPopup) {
  const handler = function (evt) {
    if (thymeAttributes.lockKeyListeners && !searchPopup.isVisible) {
      return;
    }

    // Check if the event matches the configured SEARCH_SHORTCUT
    if (
      evt.key.toLowerCase() === SEARCH_SHORTCUT.key.toLowerCase()
      && evt.shiftKey === SEARCH_SHORTCUT.shiftKey
      && evt.ctrlKey === SEARCH_SHORTCUT.ctrlKey
      && evt.metaKey === SEARCH_SHORTCUT.metaKey
    ) {
      evt.preventDefault(); // prevent any browser default
      searchPopup.toggle();
    }
  };

  window.addEventListener("keydown", handler);
  return handler;
}

export function removeSearchShortcuts(handler) {
  window.removeEventListener("keydown", handler);
}
