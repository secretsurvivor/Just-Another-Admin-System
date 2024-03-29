# Just Another Admin System :: JAAS
Advanced and High Performance Administration System for the game Garry's Mod

Currently in no working order to be used, much still needs to be done before it can be released.
### About
This is an admin system designed with performance in mind; although named in such a way it is no normal admin system. Most Garry's Mod admin systems, like ULX, use tables to hold rank information (How admin system determines if a player has access to a partiular command) - here we do no such thing, we use binary bit positions to determine such things. Tests have shown it to be 83% to 106% faster than using traditional tables. This method allows server owners and developers to add as many commands and permissions without ever affecting performance. JAAS also allows players to hold as many ranks as are added to the server without affecting performance so you can say goodbye to annoying ranks for staff members that are also donators - ranks also do not need to follow any inheritance rules allowing a fully customisable rank hierarchy.
JAAS' primary form of data storage is SQLite which has been proven to be 35% faster than reading and writing to files, the option for using MySQL is also available for servers that would like to use JAAS across multiple servers. The primary way players are going to be interacting with JAAS is through its user interface - this has been designed to be intuitive and limit faffing around in menus so you can spend less time in the menu and more time playing the game.

Security has been an important element in the development of this admin system - in my opinion an insecure admin system is a useless admin system - JAAS comes with execution logging capabilities that allow it to trace the usage of JAAS modules back to the file and line, allowing server owners to be able to track down unwanted code that may be using JAAS for any unhonest intentions. Whilst JAAS has no SQL Injection flaws itself, it cannot be assured that other addons that are downloaded along with JAAS are fully protected against the same flaw - JAAS has measures in place to make sure that if any SQL Injections have taken place, server owners and staff will be fully aware of its affects - hackers will be unable to target individual player ranks so imagine instead of a locked door to the SQL data, there is an alarm for when data has been changed.

JAAS also is trying out a new concept for controlling further access when it comes to adding players, commands, and permissions to ranks - server owners can now feel comfortable gifting these powers to staff members knowing that they won't have the ability to gift themselves access to a command/permission nor the power to give a player a rank that they shouldn't have. These are called Access Groups and these offer another layer of access control - they can be applied to ranks, commands and permissions.
## Usage
### For Server Owners
As a server owner, you have a lot of options to customise JAAS to your liking - out of the box though nothing is configured with every command and permission being available by default. From this point you can set up each rank with what they have access to or use a ready made preset.
### For Developers
JAAS is also designed to be easily coded for, I have too much experience with attempting to use code that isn't straight forward so I have attempted to the best of my ability to make using it intuitive. Although JAAS supports commands, it also supports a more open ended version that us developers have full reign over how its interpreted and used which is called permissions. They're essentially the same thing, only that commands has infrastructure supporting its execution. The main method for any developer adding code is through the JAAS Register, this is a file placed in the /lua/jaas/autorun/ file structure that will be executed on JAAS that will allow you to register files to be executed on the server, client, or shared with the choice of being executed in one of three stages; pre-initialisation, initialisation, and post-initialisation.

JAAS also offers a second option for addons that want to use JAAS but not rely on JAAS to execute their code to integrate it, they can take advantage of the JAAS-PRE skeleton file that they can include in their addons that will allow them to add JAAS commands and permissions to their code without having to worry about if JAAS has been executed before or after the addon. Developing for JAAS covers three different fields:
##### - Expanding JAAS as a platform
JAAS is not designed to be everything that any server may ever need, that would be ridiculous for a single developer to achieve (Although, this doesn't mean I won't be attempting to do so) - but JAAS has been designed to be easily expanded from its default state so that third party developers could aid in improving JAAS and its capabilities. Modules can easily be registered and added to JAAS whilst being assured to execute before commands, permissions, and user interfaces. These modules have full reign to the same resources as the core modules, even the ability to overwrite sections of core modules.
##### - Adding Commands and Permissions
Commands are a pretty well established idea in the world of admin systems with every admin system supporting them and JAAS is no different - although we do it slightly different. Instead of the names of the commands themselves being required to be unique, the combination of categories and names needs to be unique. This allows for less fear about sharing command names with other possible addons and allow developers to create context with command names within categories - with command descriptions, commands are able to have names that are short and snappy whilst still allowing users to understand what they're executing. Commands are also able to return back strings so feedback and errors can be more complex to fully describe what went wrong in its execution.

Permissions are my favourite part of JAAS, allowing developers complete freedom in the ability of limiting player access to whatever they choose with full infrastructure behind it to do all the heavy lifting. Permissions can be used to control who has access to anything from certain aspects of Garry's Mod to tabs on a user interface - they're a key that can be used to open any lock you make for it. Both commands and permissions can be easily added and removed to ranks from the comfort of the user interface at runtime.
##### - Creating UI for JAAS
This in itself covers two fields; adding tabs and settings to the already established JAAS menu or just replacing the JAAS menu entirely with something better - I'm no interface designer so I implore you to make something better.
## Features to be finished
Sadly, it is not release ready. There are still features that need to be finished and features to be explored before it can be considered ready to release. In its current state, it is merely a console based admin system that cannot even be fully used from console as not all of the commands are done yet. Some features like setting what rank can access what commands and permissions will be completely done by the user interface and I will most likely modify some of the modules to make it more efficient. This is a basic list covering what needs to be done:
+ Rank Presets - Will use its own preset language instead of Lua
+ Support Singleplayer
+ Whitelist
+ Gamemode Related Commands - Will support TTT and DarkRP
+ Language Support - Will allow other languages to be used for the user interface
+ SQL Injection Protection - Use a hashing algorithm
+ Hammer Entities - Also a Hammer fgd file for easier use in Hammer

*_Tasks that are required to make JAAS release ready_
## Credits
* secret_survivor - (All me baby!)
* Dempsy - (Encouragement and support)
## Contact
If you would like to contact me about JAAS then the best way to do so would be through [Steam](https://steamcommunity.com/id/secret_survivor/). Would be best to leave a comment explaining why you've added me so I don't ignore it.
