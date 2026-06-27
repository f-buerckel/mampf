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

    // Initialize state
    if (subtitleTrack.mode === "showing") {
      element.dataset.status = "true";
      element.style.color = "var(--primary-color, #ffcd00)";
    } else {
      subtitleTrack.mode = "hidden";
      element.dataset.status = "false";
      element.style.color = "";
    }

    element.addEventListener("click", function () {
      if (subtitleTrack.mode === "showing") {
        subtitleTrack.mode = "hidden";
        element.dataset.status = "false";
        element.style.color = "";
      } else {
        subtitleTrack.mode = "showing";
        element.dataset.status = "true";
        element.style.color = "var(--primary-color, #ffcd00)";
      }
    });
  }
}
