## Get resource info and Analyze with openai

When run getResourceinfo.sh,display resource info and analyze

## Usage

```
bash getResourceinfo.sh [OPTIONS]
```
## Options

    -c  count of getting resource information
    -p  interval of getting resource information
    -t  output log of result getting resource info
    -a  analyze getting resource info

set enviroment variables "OPENAI_API_KEY" before '-a' option run.

## Example

if execute get perf info at 2 times for 2 seconds interval,you execute command the following.

```
bash getPefinfo.sh -c 10 -p 2
```
you want analyze resource info,you run the following command.
```
bash getPefinfo.sh -c 10 -p 2 -a
```

When output result of run command, you run '-t' option
```
bash getPefinfo.sh -c 10 -p 2 -t
```

(option -a and -t cannot run together)
