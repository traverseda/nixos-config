{lib, ...}: {
  boot.kernelPatches = [
    {
      name = "disable-regdb-sig-check";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        CFG80211_REQUIRE_SIGNED_REGDB = no;
      };
    }
  ];
}
