import { Component } from "~/js/thyme/components/component";

export class SubtitleButton extends Component {
  add() {
    const video = thymeAttributes.video;
    const element = this.element;

    const tracks = video.textTracks;
    let subtitleTrack = null;
    for (let i = 0; i < tracks.length; i++) {
      if (tracks[i].kind === "subtitles" || tracks[i].kind === "captions") {
        subtitleTrack = tracks[i];
        break;
      }
    }

    if (!subtitleTrack) {
      element.style.display = "none";
      return;
    }

    // Use custom subtitle container
    subtitleTrack.mode = "hidden";

    // Initialize state
    let subtitlesEnabled = false;
    element.dataset.status = "false";
    element.style.color = "";

    let container = document.getElementById("custom-subtitle-container");
    if (!container) {
      container = document.createElement("div");
      container.id = "custom-subtitle-container";
      container.className = "thyme-custom-subtitles";
      container.setAttribute("aria-live", "polite");
      container.setAttribute("aria-atomic", "true");
      document.getElementById("hypervideo-container").appendChild(container);
    }

    const updateSubtitles = () => {
      container.replaceChildren();

      if (!subtitlesEnabled) {
        return;
      }

      if (subtitleTrack.activeCues && subtitleTrack.activeCues.length > 0) {
        let text = "";
        for (let i = 0; i < subtitleTrack.activeCues.length; i++) {
          text += subtitleTrack.activeCues[i].text + "\n";
        }
        const span = document.createElement("span");
        span.textContent = text.trim();
        container.appendChild(span);
      }
    };

    subtitleTrack.addEventListener("cuechange", updateSubtitles);
    video.addEventListener("timeupdate", updateSubtitles);

    element.addEventListener("click", function () {
      subtitlesEnabled = !subtitlesEnabled;

      if (subtitlesEnabled) {
        element.classList.remove("bi-badge-cc");
        element.classList.add("bi-badge-cc-fill");
        element.style.color = "#282828ff";
      }
      else {
        element.classList.remove("bi-badge-cc-fill");
        element.classList.add("bi-badge-cc");
        element.style.color = "";
      }

      updateSubtitles();
    });
  }
}
