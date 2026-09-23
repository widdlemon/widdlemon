# Widdlemon LuckPerms setup - run from the server console: function widdlemon:setup_luckperms
# Generated from server/luckperms-setup.txt. Idempotent; never removes users from groups.
lp creategroup untrusted
lp creategroup trusted
lp creategroup trainer
lp creategroup staff
lp creategroup admin
lp group untrusted setweight 5
lp group trusted setweight 10
lp group trainer setweight 20
lp group staff setweight 50
lp group admin setweight 100
lp group trusted parent remove default
lp group trainer parent add trusted
lp group staff parent add trainer
lp group admin parent add staff
lp group default parent add trainer
lp group untrusted meta set xaero.pac_max_claims 0
lp group trusted meta set xaero.pac_max_claims 150
lp group trainer meta set xaero.pac_max_claims 250
lp group staff meta set xaero.pac_max_claims 500
lp group admin meta set xaero.pac_max_claims 1000
lp group untrusted meta set xaero.pac_max_forceloads 0
lp group trusted meta set xaero.pac_max_forceloads 5
lp group trainer meta set xaero.pac_max_forceloads 10
lp group staff meta set xaero.pac_max_forceloads 20
lp group admin meta set xaero.pac_max_forceloads 50
lp group staff permission set ledger.commands.root true
lp group staff permission set ledger.commands.inspect true
lp group staff permission set ledger.commands.search true
lp group staff permission set ledger.commands.preview true
lp group staff permission set ledger.commands.rollback true
lp group staff permission set ledger.commands.tp true
lp group staff permission set ledger.commands.player true
lp group staff permission set ledger.commands.status true
lp group staff permission set xaero.pac_claims_moderator_mode true
lp group staff permission set spark true
lp group staff permission set cobblemon.command.stopbattle true
lp group staff permission set cobblemon.command.checkspawns true
lp group staff permission set cobblemon.command.healpokemon true
lp group staff permission set cobblemon.command.healpokemon.other true
lp group admin permission set ledger.commands.* true
lp group admin permission set xaero.pac_claims_admin_mode true
lp group admin permission set xaero.pac_claims_impersonation true
lp group admin permission set xaero.pac_claims_teleport true
lp group admin permission set xaero.pac_server_claims true
lp group admin permission set xaero.pac_parties_admin_mode true
lp group admin permission set xaero.pac_parties_impersonation true
lp group admin permission set chunky.* true
lp group admin permission set cobblemon.command.* true
lp group admin permission set styledchat.* true
lp group admin permission set luckperms.* true
