import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { inject as service } from "@ember/service";

// Summit User Group helper
async function performGroupJoin(api, targetGroupName, targetGroupId) {
  const user = api.getCurrentUser();
  if (!user) {
    const returnUrl = window.location.pathname + "?auto_join_summit=1";
    window.location.assign(`/login?return_to=${encodeURIComponent(returnUrl)}`);
    return false;
  }
  try {
    let groupId = targetGroupId;
    if (!groupId || isNaN(groupId) || groupId <= 0) {
      const groupResp = await ajax(`/groups/${encodeURIComponent(targetGroupName)}.json`);
      groupId = groupResp?.group?.id;
      if (!groupId) throw new Error(`Could not resolve ID for: ${targetGroupName}`);
    }

    try {
      await ajax(`/groups/${groupId}/join.json`, {
        type: "PUT",
        data: { usernames: user.username },
      });
    } catch (joinError) {
      const joinErrStr = JSON.stringify(joinError?.jqXHR?.responseJSON || joinError?.message || "").toLowerCase();
      if (joinErrStr.includes("already") || joinError?.jqXHR?.status === 422) {
        console.log("User is already a member via join.json.");
      } else {
        await ajax(`/groups/${groupId}/members.json`, {
          type: "PUT",
          data: { usernames: user.username },
        });
      }
    }
    return true;
  } catch (error) {
    const errorString = JSON.stringify(error?.jqXHR?.responseJSON || error?.message || "").toLowerCase();
    if (errorString.includes("already") || error?.jqXHR?.status === 422) {
      console.log("User is already a member.");
      return true;
    }
    popupAjaxError(error);
    return false;
  }
}

export default apiInitializer("1.8", (api) => {
  const user = api.getCurrentUser();

  // Global Auto-Join Listener
  if (user) {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get("auto_join_summit") === "1") {
      const cleanUrl = window.location.pathname + window.location.search.replace(/[\?&]auto_join_summit=1/, '').replace(/^&/, '?');
      window.history.replaceState({}, document.title, cleanUrl || window.location.pathname);
      performGroupJoin(api, settings.summit_group_name || "ubuntu-summit", Number(settings.required_group_id));
    }
  }

  class UbuntuSummitInterimWidget extends Component {
    @service router;
    @tracked isJoiningGroup = false;
    @tracked hasJoinedGroup = false;

    constructor(owner, args) {
      super(owner, args);
      this.checkInitialGroupMembership();
    }

    async checkInitialGroupMembership() {
      if (!this.currentUser) return;
      const requiredId = Number(settings.required_group_id);
      const groupName = settings.summit_group_name || "ubuntu-summit";
      try {
        const resp = await ajax(`/u/${encodeURIComponent(this.currentUser.username)}.json`);
        const groups = resp?.groups || resp?.user?.groups || [];
        const inGroup = groups.some(g => Number(g.id) === requiredId || g.name?.toLowerCase() === groupName.toLowerCase());
        if (inGroup) {
          this.hasJoinedGroup = true;
        }
      } catch (e) {
        console.warn("Could not verify initial group membership:", e);
      }
    }

    get currentUser() {
      return api.getCurrentUser();
    }

    get currentPath() {
      return (this.router.currentURL || window.location.pathname).toLowerCase();
    }

    get isInterimHub() {
      const isEnabled = settings.widget_enabled;
      const targetSlug = (settings.summit_category_slug || "ubuntu-summit").toLowerCase();
      return isEnabled && this.currentPath.includes(targetSlug);
    }

    get playlistUrl() {
      return settings.past_summits_playlist_url || "https://www.youtube.com/embed/videoseries?list=PLwFSk464RMxkkvScqDkfHLIx8ox0hDIDV";
    }
    get badgeText() {
      return settings.interim_badge_text || "Ubuntu Summit";
    }
    get hubTitle() {
      return settings.interim_title || "On the road to Ubuntu Summit 26.10";
    }
    get hubDescription() {
      return settings.interim_description || "The previous Ubuntu Summit has ended, but the next one will be coming soon! Watch sessions from the last iteration, register for the next, or submit your own talk for Ubuntu Summit 26.10.";
    }
    get cfpButtonLabel() {
      return settings.interim_cfp_button_label || "Submit a CFP Proposal →";
    }
    get cfpButtonUrl() {
      return settings.interim_cfp_button_url || "/c/ubuntu-summit/call-for-papers/512";
    }

    @action
    async handleInterimJoin() {
      this.isJoiningGroup = true;
      const success = await performGroupJoin(api, settings.summit_group_name || "ubuntu-summit", Number(settings.required_group_id));
      if (success) this.hasJoinedGroup = true;
      this.isJoiningGroup = false;
    }

    <template>
      {{#if this.isInterimHub}}
        <div class="ubuntu-summit-interim-hub">
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 28px; align-items: center;">
            
            <div class="interim-video-container">
              <iframe 
                src={{this.playlistUrl}} 
                title="Ubuntu Summit Past Keynotes & Sessions" 
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" 
                allowfullscreen>
              </iframe>
            </div>

            <div class="interim-actions-hub">
              <span class="interim-badge">{{this.badgeText}}</span>
              <h2>{{this.hubTitle}}</h2>
              <p>{{this.hubDescription}}</p>

              <div style="display: flex; flex-wrap: wrap; gap: 12px; align-items: center;">
                {{#if this.hasJoinedGroup}}
                  <span class="status-sharp-green">
                    ✓ You're Summit ready!
                  </span>
                {{else}}
                  <button 
                    type="button" 
                    class="btn-sharp-orange" 
                    disabled={{this.isJoiningGroup}} 
                    {{on "click" this.handleInterimJoin}}>
                    {{#if this.isJoiningGroup}}Registering...{{else}}+ Click to Register{{/if}}
                  </button>
                {{/if}}

                <a href={{this.cfpButtonUrl}} class="btn-outline-vanilla">
                  {{this.cfpButtonLabel}}
                </a>
              </div>
            </div>

          </div>
        </div>
      {{/if}}
    </template>
  }

  api.renderInOutlet("discovery-list-container-top", UbuntuSummitInterimWidget);
});
