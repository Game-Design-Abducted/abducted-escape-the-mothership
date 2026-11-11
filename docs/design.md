# Game Design Final Project

---

[General Information](#general-information)

[Game Concept](#game-concept)

[Game Story & Setting](#game-story-&-setting)

[Story Progression](#story-progression)

[Ending](#ending)

[Main Gameplay](#main-gameplay)

[Level Design](#level-design)

[Work Distribution](#work-distribution)

[Project Tracker](#project-tracker)

---

# General Information {#general-information}

## **Game Concept** {#game-concept}

Our game is a **2D action game combining Pac-Man and Tower Defense mechanics**, developed using **Godot 4 (GDScript)**.

The player moves around a Pac-Man-style maze, killing monsters that spawn and follow predefined paths, similar to enemies in a tower defense game. However, instead of placing towers, the player fights the monsters directly.

## **Game Story & Setting** {#game-story-&-setting}

The game takes place inside an **alien spacecraft**. The player is a human who has been abducted by aliens and must find a way to escape and return to Earth.

The spacecraft is overrun by hostile alien monsters. The player must survive and protect the ship's critical systems from monsters that continuously spawn from alien origins.

The player's normal weapon can defeat regular monsters, but it cannot destroy their origins because they are protected by advanced alien technology. The only weapon powerful enough to destroy them is a **special laser gun developed using alien technology**.

After fighting monsters for a certain period, the player gets an opportunity to collect the laser gun and shoot the origin. If the player misses, they must continue surviving until another opportunity appears.

### **Story Progression** {#story-progression}

**Level 1 – Destroy the Alien Egg**

* The player wakes up inside the alien spacecraft after being abducted.  
* Monsters are spawning from a mysterious alien egg.  
* The player must survive and protect the spacecraft while waiting for the alien laser gun.  
* Destroying the egg unlocks access to the spacecraft's control room.

**Level 2 – Defeat the Alien Commander**

* The player discovers that the monsters are controlled by a powerful alien commander.  
* Unlike the stationary egg in Level 1, the commander moves around the map, making it harder to hit.  
* The player must survive, obtain the laser gun, and defeat the commander before the 3-minute timer runs out.  
* After defeating the commander, the player obtains the **Navigation Core**, which contains Earth's coordinates and allows the spacecraft's navigation system to be activated.

### **Ending** {#ending}

After recovering the Navigation Core, the player activates the spacecraft's return system, sets the destination to Earth, and finally escapes.

**Main Objective:** Survive the alien invasion, destroy both monster origins using alien laser technology, and recover the Navigation Core to return home.

## **Main Gameplay** {#main-gameplay}

* Monsters continuously spawn and follow different paths around the map.  
* There will be around **3 types of monsters**, each with different speeds, HP, or movement patterns.  
* After surviving and killing monsters for a certain period, a **laser gun appears** on the map.  
* When the player collects the laser, normal gameplay pauses, allowing the player to aim and shoot at the monster origin.  
* Have **3 minutes countdown** timer to kill the origin, If the timer runs out \= the player lose,  
* **Successful shot:** The origin is destroyed, completing the level.  
* **Missed shot:** Gameplay resumes, and the player must survive another period before receiving another shooting opportunity.  
* **Time runs out:** If the player fails to destroy the origin within 3 minutes, they lose.

## **Level Design** {#level-design}

**Level 1 – Stationary Origin**

* Pac-Man-style maze with monsters following predefined routes.  
* The monster's origin is a stationary alien egg.  
* The player must survive, collect the laser, and destroy the egg.

**Level 2 – Moving Origin**

* A different maze with more challenging monster waves.  
* The monster origin is a moving monster rather than an egg.  
* The player must aim carefully to hit the moving target.

---

# Work Distribution {#work-distribution}

| Person | Main responsibility | What they actually make | Name |
| ----- | ----- | ----- | ----- |
| 1\. Map \+ Level Designer | Map Design \+ level setup | Pac-Man-style maze, collision walls, spawn points, monster paths, player starting position, Level 1 layout, Level 2 layout, placement of monster origin | Mew |
| 2\. Player \+ Combat Programmer | Main gameplay | Player movement, collision, normal attack/killing monsters, HP/lives if used, picking up the laser gun, interaction with enemies | Yang |
| 3\. Enemy \+ Wave Programmer | Tower-defense system | Enemy spawning, multiple enemy types, movement/path patterns, wave timing, difficulty progression, different speed/HP/behavior | Ploy |
| 4\. Laser \+ Level 2 Programmer | Special mechanic | Laser gun appearance timer, freeze/pause gameplay when picked up, aiming/shooting sequence, hit/miss logic, cooldown if missed, Level 1 egg target, Level 2 moving monster-origin target | Kong |
| 5\. Art \+ UI \+ Animation \+ Integration | Presentation/polish | Character sprites, enemy variants, animations, laser effects, hit/death effects, home screen, loading screen, story screen, HUD, sounds, testing/integration | Fah |

---

# Project Tracker {#project-tracker}

| Person | Task | Deadline | Checkbox |
| ----- | ----- | ----- | ----- |
| 1\. Map & Level Designer | Complete Level 1 map and monster paths | Nov 11 |  |
|  | Complete Level 2 map, moving origin path and level balancing | Nov 13 |  |
|  | Test and adjust both maps | Nov 15 |  |
| 2\. Character & UI Designer | Complete player, monsters, egg and laser sprites | Nov 12 |  |
|  | Complete animations and visual effects | Nov 14 |  |
|  | Home screen, loading screen, story and promotional document draft | Nov 15 |  |
| 3\. Player & Combat Developer | Player movement and wall collisions | Nov 11 |  |
|  | Attacking, enemy damage and player HP | Nov 13 |  |
|  | Laser pickup and combat integration | Nov 14 |  |
|  | Gameplay testing and bug fixes | Nov 15 |  |
| 4\. Monster & Wave Developer | Basic monster spawning and movement | Nov 11 |  |
|  | Three monster types and wave system | Nov 13 |  |
|  | Level 2 enemy difficulty and movement | Nov 14 |  |
|  | Gameplay testing and bug fixes | Nov 15 |  |
| 5\. Laser & Game Logic Developer | Laser gun spawning and pickup sequence | Nov 12 |  |
|  | Freeze, aim, shoot, hit/miss and retry mechanics | Nov 13 |  |
|  | Level 1 stationary origin and Level 2 moving origin | Nov 14 |  |
|  | Win/lose conditions and level transitions | Nov 15 |  |

