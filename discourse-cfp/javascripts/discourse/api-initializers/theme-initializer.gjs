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

      // Lock it down to exactly your Call for Papers category URL
      if (currentUrl.includes('/c/ubuntu-summit/call-for-papers/512') || currentUrl.endsWith('/512')) {
        return true;
      }
      
      return false; 
    }

    @action
    showLogin() {
      const route = Discourse.__container__.lookup("route:application");
      if (route) route.send("showLogin");
    }

    @action
    async submitCfpForm(e) {
      e.preventDefault();
      
      this.isSubmitting = true;
      this.submitText = "Uploading and submitting...";

      const speakerName = document.getElementById("cfp-name")?.value.trim();
      const speakerEmail = document.getElementById("cfp-email")?.value.trim();
      const talkTitle   = document.getElementById("cfp-title")?.value.trim();
      const talkAbstract= document.getElementById("cfp-abstract")?.value.trim();
      const presentationLink = document.getElementById("cfp-slides")?.value.trim();
      
      // Grab the photo file
      const photoInput = document.getElementById("cfp-photo");
      const photoFile = photoInput && photoInput.files.length > 0 ? photoInput.files[0] : null;

      if (!talkTitle || !talkAbstract) {
        alert("Please fill out both the Proposed Talk Title and Talk Abstract fields.");
        this.isSubmitting = false;
        this.submitText = "Submit Proposal";
        return;
      }

      let finalPhotoUrl = "";

      // Step 1: If they selected a file, upload it to Discourse first
      if (photoFile) {
        try {
          const formData = new FormData();
          formData.append("type", "composer");
          formData.append("file", photoFile);
          formData.append("synchronous", "true");

          const uploadResponse = await ajax("/uploads.json", {
            type: "POST",
            data: formData,
            processData: false,
            contentType: false
          });

          // Ensure it's an absolute URL
          finalPhotoUrl = uploadResponse.url.startsWith("http") 
            ? uploadResponse.url 
            : window.location.origin + uploadResponse.url;

        } catch (error) {
          alert("Failed to upload the headshot. Please ensure it is a valid image and try again.");
          this.isSubmitting = false;
          this.submitText = "Submit Proposal";
          console.error("Upload Error:", error);
          return;
        }
      } 
      // Fallback: If no photo uploaded, use their Discourse profile avatar
      else if (this.currentUser && this.currentUser.avatar_template) {
         const avatarUrl = this.currentUser.avatar_template.replace("{size}", "500"); // Pulled larger just in case
         finalPhotoUrl = window.location.origin + avatarUrl;
      }

      // Step 2: Construct Markdown using the uploaded photo URL
      const markdownBody = `
## New Ubuntu Summit CFP Proposal

<img src="${finalPhotoUrl}" width="60" height="60" style="border-radius:50%; margin-bottom:10px;" alt="Speaker Avatar" />

* **Speaker Identity:** ${speakerName} ( [@${this.currentUser.username}](${window.location.origin}/u/${this.currentUser.username}) )
* **Account Email:** ${speakerEmail}
* **Supporting Materials / Slide Link:** ${presentationLink ? `[View Attached Resource](${presentationLink})` : "None Provided"}

---

### Presentation Abstract
${talkAbstract}
`;

      // Step 3: Send the final PM
      try {
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
                <div class="cfp-field">
                  <label>Speaker Name / Handle</label>
                  <input type="text" id="cfp-name" value={{this.currentUser.name}} class="cfp-input" />
                </div>

                <div class="cfp-field">
                  <label>Contact Email</label>
                  <input type="email" id="cfp-email" value={{this.currentUser.email}} class="cfp-input" />
                </div>

                <div class="cfp-field">
                  <label>Proposed Talk Title</label>
                  <input type="text" id="cfp-title" placeholder="e.g., Optimizing Edge Workloads with Ubuntu Core" class="cfp-input" />
                </div>

                <div class="cfp-field">
                  <label>Talk Abstract</label>
                  <textarea id="cfp-abstract" placeholder="Provide a detailed description of your presentation theme, technical level, and key takeaways for attendees..." class="cfp-input"></textarea>
                </div>

		<div class="cfp-field">
		  <label>Speaker Headshot (Optional)</label>
		  <input type="file" id="cfp-photo" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" />
		  <small style="display: block; margin-top: 5px; color: var(--primary-medium);">Upload a high-resolution headshot for your speaker profile. If left blank, we will default to your forum profile picture.</small>
		</div>

                <div class="cfp-field">
                  <label>Presentation Draft / Supporting Materials Link (Optional)</label>
                  <input type="url" id="cfp-slides" placeholder="e.g., Link to slide decks, GitHub repos, or shared design drafts..." class="cfp-input" />
                  <small style="display: block; margin-top: 5px; color: var(--primary-medium);">Note: To provide a profile picture or speaker headshot, please ensure your main Discourse account avatar is up to date.</small>
                </div>

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
