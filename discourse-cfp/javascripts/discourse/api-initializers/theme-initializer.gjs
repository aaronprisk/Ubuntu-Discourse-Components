import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";

export default apiInitializer("1.8", (api) => {
  class UbuntuSummitCfp extends Component {
    @tracked submissionSuccess = false;
    @tracked isSubmitting = false;
    @tracked submitText = "Submit Proposal";

    get currentUser() {
      return api.getCurrentUser();
    }

    get isCfpCategory() {
      const currentUrl = window.location.pathname;
      return currentUrl.includes('/c/ubuntu-summit/call-for-papers/512') || currentUrl.endsWith('/512');
    }

    @action
    showLogin() {
      const route = Discourse.__container__.lookup("route:application");
      if (route) route.send("showLogin");
    }

    // Modular upload helper for multiple speaker headshots
    async uploadPhoto(file) {
      if (!file) return null;
      const formData = new FormData();
      formData.append("type", "composer");
      formData.append("file", file);
      formData.append("synchronous", "true");
      
      const res = await ajax("/uploads.json", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false
      });
      
      return res.url.startsWith("http") ? res.url : window.location.origin + res.url;
    }

    @action
    async submitCfpForm(e) {
      e.preventDefault();
      this.isSubmitting = true;
      this.submitText = "Uploading and submitting...";

      const talkTitle   = document.getElementById("cfp-title")?.value.trim();
      const talkAbstract= document.getElementById("cfp-abstract")?.value.trim();
      const presentationLink = document.getElementById("cfp-slides")?.value.trim();

      // Speaker 1
      const s1Name = document.getElementById("cfp-s1-name")?.value.trim();
      const s1Email = document.getElementById("cfp-email")?.value.trim();
      const s1Affil = document.getElementById("cfp-s1-affil")?.value.trim();
      const s1File = document.getElementById("cfp-s1-photo")?.files[0];

      // Speaker 2
      const s2Name = document.getElementById("cfp-s2-name")?.value.trim();
      const s2Affil = document.getElementById("cfp-s2-affil")?.value.trim();
      const s2File = document.getElementById("cfp-s2-photo")?.files[0];

      // Speaker 3
      const s3Name = document.getElementById("cfp-s3-name")?.value.trim();
      const s3Affil = document.getElementById("cfp-s3-affil")?.value.trim();
      const s3File = document.getElementById("cfp-s3-photo")?.files[0];

      if (!talkTitle || !talkAbstract || !s1Name || !s1Email) {
        alert("Please fill out the Primary Speaker info, Talk Title, and Abstract.");
        this.isSubmitting = false;
        this.submitText = "Submit Proposal";
        return;
      }

      try {
        // Upload files asynchronously
        let s1Url = await this.uploadPhoto(s1File);
        const s2Url = await this.uploadPhoto(s2File);
        const s3Url = await this.uploadPhoto(s3File);

        // Fallback to avatar for Speaker 1 if no photo provided
        if (!s1Url && this.currentUser && this.currentUser.avatar_template) {
            s1Url = window.location.origin + this.currentUser.avatar_template.replace("{size}", "500");
        }

        // Construct structured Markdown for Embla parser
        let markdownBody = `## New Ubuntu Summit CFP Proposal\n\n`;

        markdownBody += `### Speaker 1\n`;
        if (s1Url) markdownBody += `<img src="${s1Url}" width="60" height="60" style="border-radius:50%; margin-bottom:10px;" alt="Speaker 1" />\n`;
        markdownBody += `* **Name:** ${s1Name} ( [@${this.currentUser.username}](${window.location.origin}/u/${this.currentUser.username}) )\n`;
        markdownBody += `* **Email:** ${s1Email}\n`;
        markdownBody += `* **Affiliation:** ${s1Affil || "None"}\n\n`;

        if (s2Name) {
            markdownBody += `### Speaker 2\n`;
            if (s2Url) markdownBody += `<img src="${s2Url}" width="60" height="60" style="border-radius:50%; margin-bottom:10px;" alt="Speaker 2" />\n`;
            markdownBody += `* **Name:** ${s2Name}\n`;
            markdownBody += `* **Affiliation:** ${s2Affil || "None"}\n\n`;
        }

        if (s3Name) {
            markdownBody += `### Speaker 3\n`;
            if (s3Url) markdownBody += `<img src="${s3Url}" width="60" height="60" style="border-radius:50%; margin-bottom:10px;" alt="Speaker 3" />\n`;
            markdownBody += `* **Name:** ${s3Name}\n`;
            markdownBody += `* **Affiliation:** ${s3Affil || "None"}\n\n`;
        }

        markdownBody += `### Session Details\n`;
        markdownBody += `* **Materials:** ${presentationLink ? `[View Attached Resource](${presentationLink})` : "None Provided"}\n\n`;
        markdownBody += `---\n### Presentation Abstract\n${talkAbstract}`;

        await ajax("/posts.json", {
          type: "POST",
          data: {
            title: `[CFP Submission] ${talkTitle}`,
            raw: markdownBody,
            archetype: "private_message",
            target_recipients: "Ubuntu-Summit-Core"
          }
        });
        
        this.submissionSuccess = true;
      } catch (error) {
        alert("A network transmission error occurred. Please verify your fields and try again.");
        this.isSubmitting = false;
        this.submitText = "Submit Proposal";
        console.error("Ubuntu Summit CFP Error:", error);
      }
    }

    <template>
      {{#if this.isCfpCategory}}
        <div class="ubuntu-cfp-container">
          
          {{#if this.currentUser}}
            {{#if this.submissionSuccess}}
              <div class="cfp-success-view">
                <h2>Thank you for submitting your talk!</h2>
                <p>The Ubuntu Summit Organizing Team has received your proposal. We will review your abstract and be in touch if your session is chosen for the event.</p>
              </div>
            {{else}}
              <h2>Ubuntu Summit - Call for Papers</h2>
              <p style="margin-bottom: 25px;">Welcome! Fill out the form fields below to submit your talk for the upcoming Ubuntu Summit.</p>
              
              <form {{on "submit" this.submitCfpForm}}>
                
                <fieldset style="border: 1px solid var(--primary-low); padding: 15px; margin-bottom: 20px; border-radius: 4px;">
                    <legend style="font-weight: bold; padding: 0 10px;">Primary Speaker</legend>
                    <div class="cfp-field">
                        <label>Name / Handle</label>
                        <input type="text" id="cfp-s1-name" value={{this.currentUser.name}} class="cfp-input" required />
                    </div>
                    <div class="cfp-field">
                        <label>Account Email</label>
                        <input type="email" id="cfp-email" value={{this.currentUser.email}} class="cfp-input" required />
                    </div>
                    <div class="cfp-field">
                        <label>Affiliation / Company (Optional)</label>
                        <input type="text" id="cfp-s1-affil" placeholder="e.g., Canonical" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Speaker Headshot (Optional)</label>
                        <input type="file" id="cfp-s1-photo" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" />
                        <small style="display: block; margin-top: 5px; color: var(--primary-medium);">If left blank, we will default to your forum profile picture.</small>
                    </div>
                </fieldset>

                <fieldset style="border: 1px solid var(--primary-low); padding: 15px; margin-bottom: 20px; border-radius: 4px;">
                    <legend style="font-weight: bold; padding: 0 10px;">Speaker 2 (Optional)</legend>
                    <div class="cfp-field">
                        <label>Name</label>
                        <input type="text" id="cfp-s2-name" placeholder="Co-presenter name" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Affiliation / Company</label>
                        <input type="text" id="cfp-s2-affil" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Headshot</label>
                        <input type="file" id="cfp-s2-photo" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" />
                    </div>
                </fieldset>

                <fieldset style="border: 1px solid var(--primary-low); padding: 15px; margin-bottom: 20px; border-radius: 4px;">
                    <legend style="font-weight: bold; padding: 0 10px;">Speaker 3 (Optional)</legend>
                    <div class="cfp-field">
                        <label>Name</label>
                        <input type="text" id="cfp-s3-name" placeholder="Co-presenter name" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Affiliation / Company</label>
                        <input type="text" id="cfp-s3-affil" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Headshot</label>
                        <input type="file" id="cfp-s3-photo" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" />
                    </div>
                </fieldset>

                <fieldset style="border: 1px solid var(--primary-low); padding: 15px; margin-bottom: 20px; border-radius: 4px;">
                    <legend style="font-weight: bold; padding: 0 10px;">Session Details</legend>
                    <div class="cfp-field">
                        <label>Proposed Talk Title</label>
                        <input type="text" id="cfp-title" placeholder="e.g., Optimizing Edge Workloads with Ubuntu Core" class="cfp-input" required />
                    </div>
                    <div class="cfp-field">
                        <label>Talk Abstract</label>
                        <textarea id="cfp-abstract" placeholder="Provide a detailed description of your presentation theme, technical level, and key takeaways for attendees..." class="cfp-input" required></textarea>
                    </div>
                    <div class="cfp-field">
                        <label>Presentation Draft / Supporting Materials Link (Optional)</label>
                        <input type="url" id="cfp-slides" placeholder="e.g., Link to slide decks, GitHub repos, or shared design drafts..." class="cfp-input" />
                    </div>
                </fieldset>

                <button type="submit" class="btn btn-primary btn-large" disabled={{this.isSubmitting}}>
                  {{this.submitText}}
                </button>
              </form>
            {{/if}}

          {{else}}
            <div class="cfp-login-promo">
              <h2>Ubuntu Summit Call for Papers Portal</h2>
              <p style="margin-bottom: 20px;">You must be logged in to submit a presentation proposal. Please log in or register your Ubuntu One account to access the submission form.</p>
              <button type="button" {{on "click" this.showLogin}} class="btn btn-primary btn-large">Log In / Register</button>
            </div>
          {{/if}}

        </div>
      {{/if}}
    </template>
  }

  api.renderInOutlet("discovery-list-container-top", UbuntuSummitCfp);
});
