
{ pkgs, lib, ... }:

let
  dslrWebcamConfContent = ''
    alias dslr-webcam v4l2loopback
    options v4l2loopback exclusive_caps=1 max_buffers=2 card_label="DSLR" video_nr=10
  '';

  dslrUdevRule = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.writeScriptBin "dslr-webcam" dslrWebcamScript}/bin/dslr-webcam"
  '';

  dslrWebcamScript = ''
    #!/bin/sh
    modprobe dslr-webcam || true
    exec "${pkgs.gphoto2}/bin/gphoto2" --stdout --capture-movie | "${pkgs.ffmpeg}/bin/ffmpeg" -i - -vcodec rawvideo -pix_fmt yuv420p -f v4l2 /dev/video10
  '';
in
{
  # Ensure your system configuration includes these options:

  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];

  # Load v4l2loopback module with the required options
  boot.extraModprobeConfig = dslrWebcamConfContent;

  # Udev rule for DSLR camera
  services.udev.extraRules = dslrUdevRule;

  # Install dslr-webcam script
  environment.systemPackages = with pkgs; [
    (writeScriptBin "dslr-webcam" dslrWebcamScript)
  ];
}
