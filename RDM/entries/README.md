# Structure of RDM Entries
Remote Desktop Manager entries are exposed using a hierarchical structure. 

### A quick note on names
RDM was created 10y ago, some classes/properties are using names that were in effect when they were introduced. For instance, *Connections* are now known as *Entries*. You see, at first RDM only handled remote access technologies, AKA connections to other systems...

## example structure

```
Connection
    ... "general" properties directly at the root
    - Credentials
    - Events
    - MetaInformation
    - Security
    
    Specialized entries (most of them), contain ONE property corresponding to its type, for example...
    
    - RDP
    - SSH
    - Terminal
    ... and so on for ALL entry types 
```

The "entries" folder will therefore be organized a structure as close a possible to the Connection class, exception being of root properties that will be contained in the "Root Properties" folder.
    

