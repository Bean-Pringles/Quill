proc echoCmd(args: seq[string]) =
    echo "Echo: ", args.join(" ")

registerCommand("echo", echoCmd)
