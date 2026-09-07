{config, ...}: {
  xdg.configFile."hindsight/coding-agent.json".text = builtins.toJSON {
    apiUrl = "http://hermes.tail1905aa.ts.net:8888";
  };
}
