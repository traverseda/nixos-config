{ pkgs, config, lib, ... }:

let
  dslrWebcamConfContent = ''
    alias dslr-webcam v4l2loopback
    options v4l2loopback exclusive_caps=1 max_buffers=2 card_label="DSLR" video_nr=10
  '';

  dslrUdevRule = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.systemd}/bin/systemctl start dslr-webcam.service"
    ACTION=="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.systemd}/bin/systemctl stop dslr-webcam.service"
    ACTION=="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.kmod}/bin/modprobe -r dslr-webcam || true"
  '';

  dslrWebcamScript = ''
    #!/bin/sh
    ${pkgs.kmod}/bin/modprobe dslr-webcam || true
    # Wait up to 2 seconds for /dev/video10 to appear
    tries=0
    while [ ! -c /dev/video10 ] && [ $tries -lt 20 ]; do
        ${pkgs.coreutils}/bin/sleep 0.1
        tries=$((tries+1))
    done
    exec "${pkgs.gphoto2}/bin/gphoto2" --stdout --capture-movie | "${pkgs.ffmpeg}/bin/ffmpeg" -i - -vcodec rawvideo -pix_fmt yuv420p -f v4l2 /dev/video10
  '';

in
{
  # Ensure your system configuration includes these options:

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  # Load v4l2loopback module with the required options
  boot.extraModprobeConfig = dslrWebcamConfContent;

  # Udev rule for DSLR camera
  services.udev.extraRules = dslrUdevRule;

  # Install dslr-webcam script and systemd service
  environment.systemPackages = with pkgs; [
    (writeScriptBin "dslr-webcam" dslrWebcamScript)
    kmod
    coreutils
  ];

  systemd.services.dslr-webcam = {
    description = "DSLR Webcam Service";
    serviceConfig = {
      ExecStart = "${pkgs.writeScriptBin "dslr-webcam" dslrWebcamScript}/bin/dslr-webcam";

      Restart = "on-failure";
    };
  };
}


