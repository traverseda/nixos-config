{ pkgs, lib, ... }:

let
  dslrWebcamConfContent = ''
    alias dslr-webcam v4l2loopback
    options v4l2loopback exclusive_caps=1 max_buffers=2 card_label="DSLR" video_nr=10
  '';

  dslrUdevRule = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.systemd}/bin/systemctl start dslr-webcam.service"
    ACTION=="remove", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ENV{ID_USB_MODEL}=="Canon_Digital_Camera", RUN+="${pkgs.systemd}/bin/systemctl stop dslr-webcam.service"
  '';

  dslrWebcamScript = ''
    #!/bin/sh
    modprobe dslr-webcam || true
    exec "${pkgs.gphoto2}/bin/gphoto2" --stdout --capture-movie | "${pkgs.ffmpeg}/bin/ffmpeg" -i - -vcodec rawvideo -pix_fmt yuv420p -f v4l2 /dev/video10
  '';

  dslrWebcamService = ''
    [Unit]
    Description=DSLR Webcam Service
    After=network.target

    [Service]
    ExecStart=${pkgs.writeScriptBin "dslr-webcam" dslrWebcamScript}/bin/dslr-webcam
    ExecStop=/bin/kill -s TERM $MAINPID
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
  '';
in
{
  # Ensure your system configuration includes these options:

  boot.extraModulePackages = [ pkgs.linuxPackages.v4l2loopback ];

  # Load v4l2loopback module with the required options
  boot.extraModprobeConfig = dslrWebcamConfContent;

  # Udev rule for DSLR camera
  services.udev.extraRules = dslrUdevRule;

  # Install dslr-webcam script and systemd service
  environment.systemPackages = with pkgs; [
    (writeScriptBin "dslr-webcam" dslrWebcamScript)
  ];

  systemd.services.dslr-webcam = {
    description = "DSLR Webcam Service";
    serviceConfig = {
      ExecStart = "${pkgs.writeScriptBin "dslr-webcam" dslrWebcamScript}/bin/dslr-webcam";

      Restart = "on-failure";
    };
  };
}


