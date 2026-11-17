# Secrets and API keys for media server services.
#
# NOTE: Plain strings in Nix files are readable in /nix/store.
# For production setups, you can replace these strings with file paths:
#   jellyfinAdminPassword = { _secret = "/run/secrets/jellyfin_password"; };
# or use sops-nix / agenix.
#
# Change these default passwords before exposing the server outside your LAN!
{
  jellyfin = {
    apiKey = "jellyfin-api-key-32characters-long";
    adminPassword = "zildjian";
  };

  sonarr = {
    apiKey = "sonarr-api-key-32characters-long";
    webPassword = "zildjian";
  };

  radarr = {
    apiKey = "radarr-api-key-32characters-long";
    webPassword = "zildjian";
  };

  prowlarr = {
    apiKey = "prowlarr-api-key-32characters-long";
    webPassword = "zildjian";
  };

  seerr = {
    apiKey = "seerr-api-key-32characters-long";
  };
}
