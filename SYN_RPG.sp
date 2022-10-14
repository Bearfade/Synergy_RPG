/*
 * ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
 * Copyright (C)2020-2023 백고미(김태훈) All rights reserved.
 * ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
 * 구성 : 작성중
 * TIP : 
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define STRING(%1) %1, sizeof(%1)

#define MaxLevel 200 //만렙
#define LvSP 1 //레벨업당 줄 스킬포인트
#define LvDmg 0.02 //레벨업당 데미지 증가
#define LvDefense 0.0025 //레벨업당 방어력
#define LvHp 2
#define LvHp2 3 //~배수마다 1추가

#define HpIndex 1 //회복양
#define VampireIndex 0.05 //
#define StickIndex 0.30 //
#define RifleIndex 1.0 //
#define PistolIndex 3.0 //
#define MagnumIndex 0.02 //*
#define ShotgunIndex 2.0 //
#define CrossbowIndex 10.0 //
#define ExplosiveIndex 0.1 //*
#define HeadShotIndex 0.02 //*
#define BodyShotIndex 0.03 //*

Handle Information_HpHud[MAXPLAYERS+1]; //HP허드 = 0:백그라운드, 1:현재양, 2:숫자

Database g_Database = null;
DBStatement g_dbGetUserInfo = null;
DBStatement g_dbInsertUser = null;
DBStatement g_dbUpdateUser = null;

// Player ENUM.
enum ePlayerData
{
	g_iID,
	String:g_sAuthID[64],
	g_iLevel,
	g_iExp,
	g_iSkp,
	g_iConnects,
	//비저장데이터
	g_iMaxExp,
}
// int PlayerData[MAXPLAYERS+1][ePlayerData]; //구문법
int PlayerData[MAXPLAYERS+1][view_as<int>(ePlayerData)]; //신문법
int PlayerSkill[MAXPLAYERS+1][16];

// Prepared Statements.
char g_arrStatements[][] = 
{
	"SELECT `id`, `level`, `exp`, `skp`, `connect` FROM `player` WHERE `steam`=?",
	"INSERT INTO `player` (`id`, `steam`, `nickname`, `level`, `exp`, `skp`, `connect`) VALUES (?, ?, ?, ?, ?, ?, ?)",
	"UPDATE `player` SET `nickname`=?, `level`=?, `exp`=?, `skp`=?, `connect`=? WHERE `id`=?"
}

//크리에이트:NPC
int MAX_NPC;
enum struct npc_data {
	char Name[256];
	char Class[256];
	int Dollar;
}
npc_data NPC[64];
int MAX_SKILL;
enum struct skill_data {
	//번호 이름 설명 효과량 최대치 필요량
	char Name[256];
	char Description[256];
	int Effect;
	int Max;
	int Need;
}
skill_data Skill[16];

int HpCount[MAXPLAYERS+1] = {0, ...};

enum struct key_data {
	bool F; //플래쉬
	bool T; //스프레이
	bool E; //
	bool C; //팀 투입/철수
}
key_data Key[MAXPLAYERS+1];

public OnPluginStart()
{
	HudSynchronizer(); //허드등록
	RegisterNPC();
	RegisterSkill();
	Database.Connect(ConnectCallBack, "synergy");
	
	RegConsoleCmd("say", SayHook);
	AddCommandListener(Command_N, "dropweapon");
	AddCommandListener(Command_B, "dropammo");
	AddCommandListener(Command_G, "phys_swap");
	
	HookEvent("player_spawn", player_spawn);
	//Loop:
	for(int i = 1; i < MAX_NPC; i++) HookEntityOutput(NPC[i].Class, "OnDeath", OnNPCDeath);
}
public void OnMapStart()
{
	CreateTimer(1.0, MapIntCount, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public void OnMapEnd()
{
	if(g_Database != null) delete g_Database;
	g_Database = null;
}
public void OnClientPutInServer(int Client)
{
	SDKHook(Client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public void OnClientPostAdminCheck(int Client)
{
	if(IsClientConnectedIngame(Client))
	{
		if(g_Database != null)
		{
			LoadUser(Client, true);
			LoadSkill(Client);
		}
	}
}
public void OnClientDisconnect(int Client)
{
	SaveUser(Client, true);
}

public void OnEntityCreated(entity, const String:classname[])
{
    if(StrContains(classname, "npc", false) != -1 && IsValidEntity(entity))
	{
		SDKHook(entity, SDKHook_TraceAttack, OnEntityTraceAttack);
		SDKHook(entity, SDKHook_OnTakeDamage, OnEntityTakeDamage);
		CreateTimer(0.1, GetNPCHealth, EntIndexToEntRef(entity));
	}
}

public HudSynchronizer() //맵시작시:허드 핸들
{
	for(int Client = 1; Client <= MaxClients; Client++)
	{
		Information_HpHud[Client] = CreateHudSynchronizer(); //
	}
}
public RegisterNPC() //CreateNpc(1, "표시될이름", "클래스이름", 줄달러);
{
	CreateNpc(1, "좀비", "npc_zombie", 5);
	CreateNpc(2, "상체 좀비", "npc_zombie_torso", 3);
	CreateNpc(3, "포이즌 좀비", "npc_poisonzombie", 8);
	CreateNpc(4, "패스트 좀비", "npc_fastzombie", 15);
	CreateNpc(5, "헤드크랩", "npc_headcrab", 1);
	CreateNpc(6, "포이즌 헤드크랩", "npc_headcrab_black", 2);
	CreateNpc(7, "패스트 헤드크랩", "npc_headcrab_fast", 2);
	CreateNpc(8, "개미귀신", "npc_antlion", 7);
	CreateNpc(9, "미르미돈", "npc_antlionguard", 100);
	CreateNpc(10, "스토커", "npc_stalker", 10);
	CreateNpc(11, "스트라이더", "npc_strider", 300);
	CreateNpc(12, "보르티곤트", "npc_vortigaunt", 15);
	CreateNpc(13, "맨핵", "npc_manhack", 3);
	CreateNpc(14, "롤러마인", "npc_rollermine", 4);
	CreateNpc(15, "헬리콥터", "npc_helicopter", 300);
	CreateNpc(16, "드랍쉽", "npc_combinegunship", 300);
	CreateNpc(17, "건쉽", "npc_combinedropship", 300);
	CreateNpc(18, "콤바인", "npc_combine", 6);
	CreateNpc(19, "콤바인 솔져", "npc_combine_s", 7);
	CreateNpc(20, "메트로폴리스", "npc_metropolice", 5);
	CreateNpc(21, "좀바인", "npc_zombine", 6);
	CreateNpc(22, "터렛", "npc_turret_floor", 10);
	CreateNpc(23, "바나클", "npc_barnacle", 5);
	// npc_combine_s
	// npc_turret_floor 
}
public RegisterSkill()
{
	//번호 이름 설명 효과량 최대치 필요량
	CreateSkill(1, "HP 회복", "4초마다 체력 회복", 1, 5, 2);
	CreateSkill(2, "뱀파이어", "일정확률로 체력 회복", 1, 10, 2);
	CreateSkill(3, "헤드샷 강화", "헤드샷 데미지 +2퍼", 1, 10, 1);
	CreateSkill(4, "바디샷 강화", "몸통데미지 +3퍼", 1, 10, 1);
	CreateSkill(5, "근접무기 강화", "근접무기데미지 +30퍼", 1, 10, 1);
	CreateSkill(6, "피스톨 강화", "총알데미지 +3", 1, 10, 1);
	CreateSkill(7, "357/매그넘 강화", "총알데미지 +2퍼", 1, 10, 1);
	CreateSkill(8, "라이플 탄환 강화", "총알데미지 +1", 1, 10, 1);
	CreateSkill(9, "샷건 강화", "데미지 +2", 1, 10, 1);
	CreateSkill(10, "석궁 강화", "데미지 +10", 1, 10, 1);
	CreateSkill(11, "폭탄 강화", "폭탄데미지 +10퍼", 1, 10, 1);
}
//타이머
int count = 0;
public Action MapIntCount(Handle Timer) //1초 반복 타이머
{
	count++;
	if(g_Database == null) // Attempt to reconnect.
	{
		Database.Connect(ConnectCallBack, "synergy");
		PrintToServer("DB가 다시 연결되었습니다");
	}
	
	for(int Client = 1; Client <= MaxClients; Client++) //스킬쿨+힌트텍스트
	{
		if(IsClientConnectedIngame(Client) && !IsFakeClient(Client))
		{
			HintHud(Client); //힌트텍스트
			//KeyHintText(Client); //작동안함
			UserHud(Client); //유저허드
			HpRecovery(Client); //회복
		}
	}
}


public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(IsClientConnectedIngameAlive(victim))
	{
		UserHud(victim);
		
		float ReduceDmgPer = PlayerData[victim][g_iLevel] * LvDefense;
		if(damage >= 1.0)
		{
			damage *= 1.0 - (ReduceDmgPer);
		}
		else damage = 1.0;
		
	}
	return Plugin_Changed;
}
public Action GetNPCHealth(Handle Timer, any ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity == -1) return Plugin_Handled;
	if(IsValidEntity(entity))
	{
		int hp = GetEntProp(entity, Prop_Data, "m_iHealth");	
		SetClientMaxHealth(entity, hp);
	}
	return Plugin_Continue;
}
public Action OnEntityTakeDamage(int Entity, int &Attacker, int &inflictor, float &damage, int &damagetype, int &i_weapon, float damageForce[3], float damagePosition[3])
{
	//시너지:데미지타입 
	//크로우바, 스턴스틱, 파이프(weapon_pipe) : 128
	//피스톨, 357, smg, ar2, 데저트이글(weapon_degle), mp5(weapon_mp5k), 콤바인 펄스 라이플(weapon_mg1) : 2[뷸렛]
	//smg폭탄(inf:grenade_ar2), 수류탄(inf:npc_grenade_frag, weapon_frag), rpg(inf:rpg_missile, weapon_rpg), 트립마인(inf:npc_tripmine), 슬램(inf:npc_satchel, weapon_slam) : 64
	//코어볼 : 1
	//샷건(weapon_shotgun) : 536870914
	//크로스보우(inf:crossbow_bolt) : 4096
	
	if(IsClientConnectedIngame(Attacker))
	{
		char name[128]; GetEdictClassname(Entity, name, sizeof(name));
		if(IsValidEntity(Entity))
		{
			if(damagetype == 1)
			{
				PlayerData[Attacker][g_iExp] += FloatToInt(damage);
			}
		}
	}
	return Plugin_Changed;
}
public OnNPCDeath(const char[] Output, int Entity, int Killer, float Delay)
{
	if(IsClientConnectedIngame(Killer))
	{
		if(Entity != -1)
		{
			char ClassName[255]; GetEdictClassname(Entity, ClassName, 255);
			for(int X = 1; X < MAX_NPC; X++)
			{
				if(StrEqual(ClassName, NPC[X].Class) && NPC[X].Dollar > 0)
				{
					//카솟 점수올리기 할줄모름
					// char dname[32], dtype[32];
					// Format(dname, sizeof(dname), "dis_%d", Entity);
					// Format(dtype, sizeof(dtype), "%d", GetConVarInt(cvType));
					// int ent = CreateEntityByName("env_entity_dissolver");
					// if(ent>0)
					// {
						// DispatchKeyValue(NPC, "targetname", dname);
						// DispatchKeyValue(ent, "dissolvetype", dtype);
						// DispatchKeyValue(ent, "target", dname);
						// AcceptEntityInput(ent, "Dissolve");
						// AcceptEntityInput(ent, "kill");
					// }
					SetEntProp(Killer, Prop_Data, "m_iFrags", GetClientFrags(Killer) + NPC[X].Dollar);
					
					SetHudTextParams(-1.0, 0.45, 2.0, 255, 0, 0, 200, 1); //빨강
					ShowHudText(Killer, 5, "+%i\n ", NPC[X].Dollar);
					
					//PrintToChat(Killer, "\x04[백곰] - \x01당신은 \x04[NPC:엑윽]\x01을 죽여서\x04[%d]\x01달러를 얻었습니다.", Roll);
					

					// PrintToChat(Killer, "\x07FFFFFF[백고미] You Got \x07FF0000%d \x07FFFFFFEXP! \x07CFFF24[+%d]포인트", NPC_Dollar[X], Roll);
					PlayerData[Killer][g_iExp] += NPC[X].Dollar;
					if(PlayerData[Killer][g_iExp] > PlayerData[Killer][g_iMaxExp]) LevelUp(Killer); //레벨업
					
					//Sound("ambient/machines/machine1_hit2.wav", _, Killer);
					
					//Format(TempString, 255, "+%i ", StringToInt(Index_NPC[X][1]));
					//RedHudSayToClient(Killer, TempString);
					
					break;
				}
			}
			UserHud(Killer); //유저허드
		}
	}
}
public Action OnEntityTraceAttack(int Entity, int &Attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	//코어볼은 데미지 확인불가
	if(IsClientConnectedIngame(Attacker))
	{
		//시너지:데미지타입 
		//크로우바, 스턴스틱, 파이프(weapon_pipe) : 128
		//피스톨, 357, smg, ar2, 데저트이글(weapon_degle), mp5(weapon_mp5k), 콤바인 펄스 라이플(weapon_mg1) : 2[뷸렛]
		//smg폭탄(inf:grenade_ar2), 수류탄(inf:npc_grenade_frag, weapon_frag), rpg(inf:rpg_missile, weapon_rpg), 트립마인(inf:npc_tripmine), 슬램(inf:npc_satchel, weapon_slam) : 64
		//코어볼 : 1
		//샷건(weapon_shotgun) : 536870914
		//크로스보우(inf:crossbow_bolt) : 4096
		char npcname[128]; GetEdictClassname(Entity, npcname, sizeof(npcname));
		if(IsValidEntity(Entity))
		{
			//무기 관련
			char InflictorName[128]; GetEdictClassname(inflictor, InflictorName, sizeof(InflictorName));
			int activeweapon = GetEntPropEnt(Attacker, Prop_Send, "m_hActiveWeapon");
			char ActiveWeaponName[32]; GetEdictClassname(activeweapon, ActiveWeaponName, sizeof(ActiveWeaponName));
			char AttackerWeaponName[32]; GetClientWeapon(Attacker, AttackerWeaponName, sizeof(AttackerWeaponName));
			//PrintToChat(Attacker, "히트그룹:%d, 데미지타입(%d) / %s, %s, %s", hitgroup, damagetype, InflictorName, ActiveWeaponName, AttackerWeaponName); 
			
			SetEntProp(Entity, Prop_Data, "m_takedamage", 2, 1); //무적해제
			//레벨 데미지
			damage *= 1.0 + (PlayerData[Attacker][g_iLevel] * LvDmg);
			//무기데미지 강화
			if(damagetype == 128) damage *= StickDamage(Attacker);
			if(damagetype == DMG_BULLET)
			{
				damage += RifleDamage(Attacker, AttackerWeaponName);
				damage += PistolDamage(Attacker, AttackerWeaponName);
				damage *= MagnumDamage(Attacker, AttackerWeaponName);
			}
			if(damagetype == 536870914)
			{
				damage += ShotgunDamage(Attacker, AttackerWeaponName);
			}
			if(damagetype == 4096)
			{
				if(StrEqual(InflictorName, "crossbow_bolt", false)) damage += CrossbowDamage(Attacker, AttackerWeaponName);
			}
			if(damagetype == DMG_BLAST) //폭발물
			{
				damage *= ExplosiveDamage(Attacker, InflictorName);
			}
			//부위 데미지 강화
			if(hitgroup == 1) damage *= HeadShot(Attacker);
			else damage *= BodyShot(Attacker);
			
			int maxhp = GetClientMaxHealth(Entity);
			int hp = GetEntProp(Entity, Prop_Data, "m_iHealth") - FloatToInt(damage);
			
			int HPPercent = RoundToCeil((float(hp) / float(maxhp)) * 100);
			int intHPBAR = HPPercent/5;
			char barblack[256]; Format(barblack, sizeof(barblack), "□□□□□□□□□□□□□□□□□□□□");
			for(int i = 0; i < intHPBAR; i++) ReplaceStringEx(barblack, sizeof(barblack), "□", "■", -1, -1, false);
			for(int i = 1; i < MAX_NPC; i++)
			{
				if(StrEqual(npcname, NPC[i].Class))
				{
					//int HitGroup = TR_GetHitGroup();
					VamPire(Attacker, damage);
					//데미지 계산 후
					PrintCenterText(Attacker, "%s : %s [%d/%d] -%dHP", NPC[i].Name, barblack, hp, maxhp, FloatToInt(damage));
					float addexp = damage;
					if(addexp < 1.0) addexp = 1.0;
					PlayerData[Attacker][g_iExp] += FloatToInt(addexp);
					if(PlayerData[Attacker][g_iExp] > PlayerData[Attacker][g_iMaxExp]) LevelUp(Attacker); //레벨업
					
					break;
				}
			}
			UserHud(Attacker);
		}
	}
	return Plugin_Changed;
}
public Action SayHook(int Client, int Args)
{
	//World:
	if(Client == 0) return Plugin_Handled;
	//Declare:
	char Arg[256], buffer[256];
	//Initialize:
	GetCmdArgString(Arg, sizeof(Arg));
	//Clean:
	StripQuotes(Arg);
	TrimString(Arg);
	
	Format(buffer, sizeof(buffer), "\x07489CFF%N \x01: \x07FFFFFF%s - \x07C6FFFFLv.%d", Client, Arg, PlayerData[Client][g_iLevel]); //경찰
	SayText2ToAll(Client, buffer);
	PrintToServer(buffer);
	
	return Plugin_Handled;
}

public player_spawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	int Client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientConnectedIngame(Client)) //인간
	{
		int hp = GetClientHealth(Client) + (PlayerData[Client][g_iLevel] * LvHp) + GetHp2(Client);
		SetEntProp(Client, Prop_Data, "m_iHealth", hp, 1);
		SetClientMaxHealth(Client, hp);
		if(GetClientMaxHealth(Client) < 100) SetClientMaxHealth(Client, 100 + (PlayerData[Client][g_iLevel] * LvHp) + GetHp2(Client));
	}
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsClientConnectedIngame(Client)) //플레이어
	{
		if(impulse == 201) //스프레이 t
		{
			if(!Key[Client].T)
			{
				PrintToChat(Client, "스프레이");
				
				Key[Client].T = true;
			}
			else Key[Client].T = false;
			
		}
		if(impulse == 100) //플래쉬 f
		{
			if(!Key[Client].F)
			{
				PrintToChat(Client, "플래쉬");
				
				Key[Client].F = true;
			}
			else Key[Client].F = false;
		}
		if(impulse == 50) //팀투입/철수 c
		{
			if(!Key[Client].C)
			{
				//PrintToChat(Client, "팀투입/철수");
				LearnSkill(Client, 0);
				
				Key[Client].C = true;
			}
			else Key[Client].C = false;
		}
	}
	return Plugin_Continue;
}
public Action Command_N(int Client, const char[] command, int argc) //N키
{
	if(IsClientInGame(Client) && IsPlayerAlive(Client))
	{
		float ReduceDmgPer = (PlayerData[Client][g_iLevel] * LvDefense) * 100;
		
		char s_Name[512];
		Menu menu = new Menu(StetMenu_Handler, MENU_ACTIONS_ALL);
		Format(s_Name, sizeof(s_Name), "▬▬▬▬▬▬ 내 정보 [MyInfo] ▬▬▬▬▬▬\n \n스킬포인트 : %d\n", PlayerData[Client][g_iSkp]);
		Format(s_Name, sizeof(s_Name), "%s최대 체력 : %d\n", s_Name, GetClientMaxHealth(Client));
		Format(s_Name, sizeof(s_Name), "%s데미지 : %.1f 퍼센트 증가\n", s_Name, (PlayerData[Client][g_iLevel] * LvDmg) * 100);
		Format(s_Name, sizeof(s_Name), "%s데미지감소 : %.2f 퍼센트\n \n", s_Name, ReduceDmgPer);
		
		int skillid = 0;
		skillid = FindSkillIdByName("HP 회복");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%sHP회복량 : 4초마다 +%dHP\n", s_Name, (PlayerSkill[Client][skillid] * HpIndex));
		
		skillid = FindSkillIdByName("뱀파이어");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s뱀파이어 : 데미지의 %.2f퍼 회복\n", s_Name, (PlayerSkill[Client][skillid] * VampireIndex) * 100);
		
		skillid = FindSkillIdByName("헤드샷 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s헤드샷 : %.2f퍼 증가\n", s_Name, (PlayerSkill[Client][skillid] * HeadShotIndex) * 100);
		
		skillid = FindSkillIdByName("바디샷 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s바디샷 : %.2f퍼 증가\n", s_Name, (PlayerSkill[Client][skillid] * BodyShotIndex) * 100);
		
		skillid = FindSkillIdByName("근접무기 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s근접 : %.2f퍼 증가\n", s_Name, (PlayerSkill[Client][skillid] * StickIndex) * 100);
		
		skillid = FindSkillIdByName("피스톨 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s피스톨 : +%.1f\n", s_Name, (PlayerSkill[Client][skillid] * PistolIndex));
		
		skillid = FindSkillIdByName("357/매그넘 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s357/매그넘 : %.2f퍼 증가\n", s_Name, (PlayerSkill[Client][skillid] * MagnumIndex) * 100);
		
		skillid = FindSkillIdByName("라이플 탄환 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s라이플 : +%.1f\n", s_Name, (PlayerSkill[Client][skillid] * RifleIndex));
		
		skillid = FindSkillIdByName("샷건 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s샷건 : +%.1f\n", s_Name, (PlayerSkill[Client][skillid] * ShotgunIndex));
		
		skillid = FindSkillIdByName("석궁 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s석궁 : +%.1f\n", s_Name, (PlayerSkill[Client][skillid] * CrossbowIndex));
		
		skillid = FindSkillIdByName("폭탄 강화");
		if(PlayerSkill[Client][skillid] != 0) Format(s_Name, sizeof(s_Name), "%s폭발류 : %.1f퍼 증가\n", s_Name, (PlayerSkill[Client][skillid] * ExplosiveIndex) * 100);
		
		Format(s_Name, sizeof(s_Name), "%s \n ", s_Name);
		menu.SetTitle(s_Name);
		
		menu.AddItem("데이터로드", "데이터 재로드");	
		
		menu.ExitBackButton = false;
		menu.ExitButton = true;
		menu.Display(Client, MENU_TIME_FOREVER);

		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public int StetMenu_Handler(Menu menu, MenuAction action, int Client, int Select)
{
	switch(action)
	{
		case MenuAction_Start:
		{
			//
		}
		case MenuAction_Select:
		{
			char Menus[256];
			menu.GetItem(Select, Menus, sizeof(Menus));
			if(StrEqual(Menus, "데이터로드", false))
			{
				if(g_Database != null)
				{
					LoadUser(Client, true);
					LoadSkill(Client);
				}
				RefreshData(Client);
			}
		}
		case MenuAction_Cancel:
		{
			//if(Select == MenuCancel_ExitBack) F3MainMenu(Client);
		}
		case MenuAction_End: delete menu;
	}
	return 0;
}

public Action Command_B(int Client, const char[] command, int argc) //B키
{
	if(IsClientConnectedIngame(Client))
	{	
		char s_Name[256];
		Menu menu = new Menu(StetMenu_Handler, MENU_ACTIONS_ALL);
		Format(s_Name, sizeof(s_Name), "▬▬▬▬▬▬ asdfyInfo] ▬▬▬▬▬▬\n \n스킬포인트 : %d\n", PlayerData[Client][g_iSkp]);
		menu.SetTitle(s_Name);
		
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf");	
		menu.AddItem("", "sdf", ITEMDRAW_IGNORE);	
		menu.AddItem("", "sdf", ITEMDRAW_IGNORE);
		menu.AddItem("", "sdf2");
		menu.AddItem("", "sdf2");
		
		menu.ExitBackButton = false;
		menu.ExitButton = true;
		menu.Display(Client, MENU_TIME_FOREVER);

		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action Command_G(int Client, const char[] command, int argc) //G키
{
	if(IsClientInGame(Client) && IsPlayerAlive(Client))
	{
		PrintToChat(Client, "G키");
	}
	return Plugin_Continue;
}
//허드
public void HintHud(int Client)
{
	if(!IsClientConnectedIngame(Client)) return;
	if(IsFakeClient(Client)) return;
	
	//sendHintTextMsg(Client, "%d초", count);
}
public void UserHud(int Client)
{
	if(!IsClientConnectedIngame(Client)) return;
	if(IsFakeClient(Client)) return;
	
	char HP_Hud[512];
	int hp = GetClientHealth(Client);
	int maxhp = GetEntProp(Client, Prop_Data, "m_iMaxHealth");
	int armor = GetEntProp(Client, Prop_Data, "m_ArmorValue");
	
	char ArmorText[32]; Format(ArmorText, sizeof(ArmorText), "(방어력:%d)", armor);
	//PlayerData[Client][g_iExp]++;
	float expper = (float(PlayerData[Client][g_iExp]) / float(PlayerData[Client][g_iMaxExp])) * 100.0;
	
	Format(HP_Hud, sizeof(HP_Hud), "Lv.%d (%.1f%%)\n", PlayerData[Client][g_iLevel], expper);
	Format(HP_Hud, sizeof(HP_Hud), "%sHP : %d / %d %s\n", HP_Hud, hp, maxhp, armor > 0 ? ArmorText : "");
	
	if(PlayerData[Client][g_iExp] > PlayerData[Client][g_iMaxExp]) LevelUp(Client);
	
	SetHudTextParams(0.03, 0.03, 2.0, 255, 255, 255, 0, 1);
	ShowSyncHudText(Client, Information_HpHud[Client], "%s", HP_Hud);
}

//데이터베이스
public void ConnectCallBack (Database hDB, const char[] error, any data)
{
	if(hDB == null)
	{
		SetFailState("Database failure: %s", error);
		return;
	}
	g_Database = hDB;
	g_Database.SetCharset("utf8");
    //CreateTables();
}

public void LoadUser(int Client, bool Connect)
{
	if(!IsClientConnectedIngame(Client)) return;
	
	char sAuthID[64];
	char sName[MAX_NAME_LENGTH];
	char Query[256];
	int id=0, lv=1, exp=0, skp=LvSP, connect=0;
	int iID = 0; int iConnects = 0;

	GetClientAuthId(Client, AuthId_Steam2, sAuthID, sizeof(sAuthID), true);
	//GetClientIP(Client, sIP, sizeof(sIP));
	GetClientName(Client, sName, sizeof(sName));

	if (g_dbGetUserInfo == null)
	{
		// Create the prepared statement real quick.
		char sErr[255];
		g_dbGetUserInfo = SQL_PrepareQuery(g_Database, g_arrStatements[0], sErr, sizeof(sErr));
		PrintToServer(g_arrStatements[0]);

		if (g_dbGetUserInfo == null)
		{
			LogMessage("LoadUser() :: Error creating prepared statement (g_dbGetUserInfo) - %s", sErr);
			PrintToChat(Client, "\x07FFFFFF데이터 로드 실패[1]");
			return;
		}
	}
	SQL_BindParamString(g_dbGetUserInfo, 0, sAuthID, false);

	if(!SQL_Execute(g_dbGetUserInfo)) //예외처리
	{
		char sQueryErr[255];
		SQL_GetError(g_Database, sQueryErr, sizeof(sQueryErr));
		
		LogMessage("LoadUser() :: Couldn't execute prepared statement (g_dbGetUserInfo). Error - %s", sQueryErr);
		PrintToChat(Client, "\x07FFFFFF데이터 로드 실패[2]");
		return;
	}
	
	PrintToServer("%N의 데이터 : %s", Client, SQL_GetRowCount(g_dbGetUserInfo) < 1 ? "없음" : "있음");
	if (SQL_GetRowCount(g_dbGetUserInfo) < 1) //데이터 없을시
	{
		// Let's enter the user into the database.
		// Check if the `g_dbInsertUser` prepared statement is created.
		if (g_dbInsertUser == null)
		{
			char sErr[255];
			g_dbInsertUser = SQL_PrepareQuery(g_Database, g_arrStatements[1], sErr, sizeof(sErr));
			//"INSERT INTO `player` (`id`, `steam`, `nickname`, `level`, `exp`, `skp`) VALUES (?, ?, ?, ?, ?, ?)"
			PrintToServer(g_arrStatements[1]);
			if (g_dbInsertUser == null)
			{
				LogMessage("LoadUser() :: Error creating prepared statement (g_dbInsertUser) - %s", sErr);
				PrintToChat(Client, "\x07FFFFFF데이터 로드 실패[3]");
				return;
			}
		}
		// Fill out defaults that need values.
		SQL_BindParamInt(g_dbInsertUser, 0, id);
		SQL_BindParamString(g_dbInsertUser, 1, sAuthID, false);
		SQL_BindParamString(g_dbInsertUser, 2, sName, false);
		SQL_BindParamInt(g_dbInsertUser, 3, lv);
		SQL_BindParamInt(g_dbInsertUser, 4, exp);
		SQL_BindParamInt(g_dbInsertUser, 5, skp);
		SQL_BindParamInt(g_dbInsertUser, 6, connect);
		
		if (!SQL_Execute(g_dbInsertUser))
		{
			char sQueryErr[255]; SQL_GetError(g_Database, sQueryErr, sizeof(sQueryErr));
			LogMessage("LoadUser() :: Couldn't execute prepared statement (g_dbInsertUser). Error - %s", sQueryErr);
			PrintToChat(Client, "\x07FFFFFF데이터 로드 실패[4]");
			
			return;
		}
		
		iID = SQL_GetInsertId(g_Database); //PrimaryKey 값
		PrintToChat(Client, "\x07FFFFFF서버에 처음 오신것을 환영합니다. 처음이 아니시라면 N키를 눌러 데이터 재로드를 해주세요.");
	}
	else //데이터발견
	{
		Format(sAuthID, sizeof(sAuthID), "디버그테스트");
		Format(sName, sizeof(sName), "디버그테스트");
		while (SQL_FetchRow(g_dbGetUserInfo))
		{
			//불러올값 : `id`, `level`, `exp`, `skp`, `connect`
			//SQL_FetchString(g_dbGetUserInfo, 1, sAuthID, sizeof(sAuthID));
			iID = SQL_FetchInt(g_dbGetUserInfo, 0);
			lv = SQL_FetchInt(g_dbGetUserInfo, 1);
			exp = SQL_FetchInt(g_dbGetUserInfo, 2);
			skp = SQL_FetchInt(g_dbGetUserInfo, 3);
			connect = SQL_FetchInt(g_dbGetUserInfo, 4); 
			
			iConnects = connect;

			Format(Query, sizeof(Query), "%N : [%d] = Steam=%s, lv=%d, exp=%d, skp=%d, con=%d", Client, iID, sAuthID, lv, exp, skp, connect);
			//SQL_Query(g_Database, Query);
			PrintToServer(Query);
		}
	}

	//값 복사
	PlayerData[Client][g_iID] = iID;
	strcopy(PlayerData[Client][g_sAuthID], 64, sAuthID);
	PlayerData[Client][g_iLevel] = lv;
	PlayerData[Client][g_iExp] = exp;
	PlayerData[Client][g_iSkp] = skp;
	PlayerData[Client][g_iConnects] = iConnects;
	
	Expset(Client);
	
	// Add onto the connects count if it's a connect.
	if(Connect)
	{
		PlayerData[Client][g_iConnects] = PlayerData[Client][g_iConnects] + 1;
		Format(Query, sizeof(Query), "UPDATE `player` SET `connect`=%i WHERE `id`=%i", PlayerData[Client][g_iConnects], PlayerData[Client][g_iID]);
		SQL_Query(g_Database, Query);
	}
}
public bool SaveUser(int Client, bool bReset)
{
	// Check if the client's ID is higher than 0. < 나중에해
	if (PlayerData[Client][g_iID] < 1) 
	{
		PrintToServer("저장 취소 : 잘못된 계정값 0");
		return false;
	}
	
	char sName[MAX_NAME_LENGTH]; GetClientName(Client, sName, sizeof(sName));
	
	// Create Update prepared statement if it doesn't exist.
	if (g_dbUpdateUser == null)
	{
		char sErr[255];
		g_dbUpdateUser = SQL_PrepareQuery(g_Database, g_arrStatements[2], sErr, sizeof(sErr));
		PrintToServer(g_arrStatements[2]);
		//`nickname`=?, `level`=?, `exp`=?, `skp`=?, `connect`=? WHERE `id`=?
		if (g_dbUpdateUser == null)
		{
			LogMessage("SaveUser() :: Error creating prepared statement (g_dbUpdateUser) - %s", sErr);
			return false;
		}
	}
	else PrintToServer("SaveUser Fail : g_dbUpdateUser != null 입니다");
	
	// Let's now update some values (e.g. add on time).
	// SQL_BindParamString(g_dbUpdateUser, 0, PlayerData[Client][g_sCurIP], false);
	SQL_BindParamString(g_dbUpdateUser, 0, sName, false); //닉네임
	SQL_BindParamInt(g_dbUpdateUser, 1, PlayerData[Client][g_iLevel]); //레벨
	SQL_BindParamInt(g_dbUpdateUser, 2, PlayerData[Client][g_iExp]); //경험치
	SQL_BindParamInt(g_dbUpdateUser, 3, PlayerData[Client][g_iSkp]); //스킬포
	SQL_BindParamInt(g_dbUpdateUser, 4, 0); //커넥트
	SQL_BindParamInt(g_dbUpdateUser, 5, PlayerData[Client][g_iID]); //ID
	
	if (!SQL_Execute(g_dbUpdateUser))
	{
		char sQueryErr[255];
		SQL_GetError(g_Database, sQueryErr, sizeof(sQueryErr));
		
		LogMessage("SaveUser() :: Couldn't execute prepared statement (g_dbUpdateUser). Error - %s", sQueryErr);
		
		return false;
	}

	if (bReset)
	{
		ResetData(Client);
	}
	
	//백고미 추가:
	if(g_dbUpdateUser != null) g_dbUpdateUser = null; 
	
	return true;
}
public void ResetData(int Client)
{
	PlayerData[Client][g_iID] = -1;
	PlayerData[Client][g_iLevel] = 1;
	PlayerData[Client][g_iExp] = 0;
	PlayerData[Client][g_iSkp] = LvSP;
	PlayerData[Client][g_iConnects] = 0;
	for(int x = 1; x < MAX_SKILL; x++)
	{
		PlayerSkill[Client][x] = 0;
	}
}

public void LoadSkill(int Client)
{
	if(!IsClientConnectedIngame(Client)) return;
	if(IsFakeClient(Client)) return;
	
	if(g_Database != INVALID_HANDLE)
	{
		char steamID[64]; GetClientAuthId(Client, AuthId_Steam2, steamID, sizeof(steamID));
		
		char Query[128];
		Format(Query, sizeof(Query), "SELECT * FROM skill WHERE steamid = '%s';", steamID);
		SQL_TQuery(g_Database, SQL_SelectSkill, Query, Client, DBPrio_High);
	}
}
public SQL_SelectSkill(Handle:owner, Handle:handle, const String:error[], any:Client) //스킬 정보 불러오기
{
	if(IsClientConnectedIngame(Client))
	{
		if(handle == INVALID_HANDLE) PrintToServer("[SQL] Error : %s", error);
		else if(SQL_GetRowCount(handle)) // 데이터 발견
		{
			if(SQL_HasResultSet(handle))
			{
				while(SQL_FetchRow(handle))
				{
					int s_ID;
					int s_Skill;
					s_ID = GetIntByFeildName(handle, "skillid"); //SQL_FetchInt(handle, 3);
					s_Skill = GetIntByFeildName(handle, "count"); //SQL_FetchInt(handle, 4);
					
					PlayerSkill[Client][s_ID] = s_Skill;
				}
			}
		}
	}
}
//스킬데이터저장
public SkillSave(Client, x) //스킬 지정 저장
{
	if(IsClientConnectedIngame(Client))
	{
		char steamID[64], user_name[32], Query[256];
		GetClientName(Client, user_name, sizeof(user_name));
		if(GetClientAuthId(Client, AuthId_Steam2, steamID, sizeof(steamID)))
		{
			if(g_Database != INVALID_HANDLE && !IsFakeClient(Client))
			{
				SaveUser(Client, false);
				
				bool checks = false;
				Format(Query, sizeof(Query), "SELECT * FROM skill WHERE skillid = '%i' and steamid = '%s';", x, steamID);//ORDER BY num DESC LIMIT 1
				SQL_LockDatabase(g_Database);
				DBResultSet results = SQL_Query(g_Database, Query);
				if(results == null) 
				{
					SQL_UnlockDatabase(g_Database);
					PrintToChat(Client, "스킬 데이터 유무 확인 실패.");
					//LogError("[%s] : 아이템 데이터 유무 확인 실패", curdate);
					return false;
				}
				SQL_UnlockDatabase(g_Database);
				int rows = SQL_GetRowCount(results);
				if(rows == 0) checks = false; //데이터가 없을때
				else //데이터 있을때
				{
					checks = true;
					results.FetchRow(); //index = results.FetchInt(0);
				}
				delete results;
				
				
				if(!checks) //처음 찍을시 데이터생성
				{
					Format(Query, sizeof(Query), "INSERT INTO skill(id, steamid, nickname, skillid, count) VALUES('0', '%s', '%s', %d, %d);", steamID, user_name, x, PlayerSkill[Client][x]);
					SQL_Query(g_Database, Query); 
				}
				else
				{
					//데이터가 있으면 업데이트
					Format(Query, sizeof(Query), "UPDATE skill SET count = '%i' WHERE steamid = '%s' AND skillid = '%i'", PlayerSkill[Client][x], steamID, x);
					SQL_Query(g_Database, Query); 
				}
			}
		}
	}
	return false;
}


//세팅
public LevelUp(Client) //레벨업 세팅
{
	if(IsClientConnectedIngame(Client))
	{
		if(PlayerData[Client][g_iLevel] < MaxLevel)
		{
			PlayerData[Client][g_iExp] = PlayerData[Client][g_iExp]-PlayerData[Client][g_iMaxExp];
			PlayerData[Client][g_iLevel]++;
			PlayerData[Client][g_iSkp] += LvSP;
			Expset(Client);
			PrintToChatAll("\x07ADFFA6[%N]\x07FFFFFF님께서 레벨업 하셨습니다. \x05%d \x01-> \x04%d", Client, PlayerData[Client][g_iLevel] - 1, PlayerData[Client][g_iLevel]);
			SaveUser(Client, false);
			Sound("ambient/energy/whiteflash.wav", _, Client, true);
			
			RefreshData(Client);
		}
		else
		{
			PrintToChat(Client, "\x04[만렙] - 더이상 레벨업 불가능");
		}
	}
}
public Expset(Client) //경험치 세팅
{
	if(IsClientConnectedIngame(Client))
	{
		if(PlayerData[Client][g_iExp] < 0) PlayerData[Client][g_iExp] = 1; //음수값일시 1으로 만들어줌
		if(PlayerData[Client][g_iMaxExp] < 0) PlayerData[Client][g_iMaxExp] = 1; //음수값일시 1으로 만들어줌
		
		if(1 <= PlayerData[Client][g_iLevel] < 10) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 100;
		if(10 <= PlayerData[Client][g_iLevel] < 20) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 175;
		if(20 <= PlayerData[Client][g_iLevel] < 30) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 200;
		if(30 <= PlayerData[Client][g_iLevel] < 40) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 225;
		if(40 <= PlayerData[Client][g_iLevel] < 50) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 250;
		if(50 <= PlayerData[Client][g_iLevel] < 60) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 380;
		if(60 <= PlayerData[Client][g_iLevel] < 70) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 400;
		if(70 <= PlayerData[Client][g_iLevel] < 80) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 430;
		if(80 <= PlayerData[Client][g_iLevel] < 90) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 460;
		if(90 <= PlayerData[Client][g_iLevel] < 100) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 500;
		if(100 <= PlayerData[Client][g_iLevel] < 110) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 650;
		if(110 <= PlayerData[Client][g_iLevel] < 120) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 700;
		if(120 <= PlayerData[Client][g_iLevel] <= 200) PlayerData[Client][g_iMaxExp] = PlayerData[Client][g_iLevel] * 800;
	}
}
public RefreshData(int Client)
{
	if(IsClientConnectedIngame(Client))
	{
		int hp = 100 + (PlayerData[Client][g_iLevel] * LvHp) + GetHp2(Client);
		int currenthp = GetClientHealth(Client);
		SetEntProp(Client, Prop_Data, "m_iHealth", currenthp + (PlayerData[Client][g_iLevel] * LvHp) + GetHp2(Client), 1);
		SetClientMaxHealth(Client, hp);
		if(GetClientMaxHealth(Client) < 100) SetClientMaxHealth(Client, 100 + (PlayerData[Client][g_iLevel] * LvHp) + GetHp2(Client));
	}
}

//스킬
public HpRecovery(int Client)
{
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("HP 회복");
		if(skillid == 0) return;
		if(PlayerSkill[Client][skillid] < 1) return;
		HpCount[Client]++;
		if(HpCount[Client] >= 4)
		{
			HpCount[Client] = 0;
			
			int maxhp = GetClientMaxHealth(Client);
			int hp = GetClientHealth(Client);
			if(maxhp >= hp)
			{
				int hp2 = hp + (PlayerSkill[Client][skillid] * HpIndex);
				if(hp2 >= maxhp) hp2 = maxhp;
				SetEntProp(Client, Prop_Data, "m_iHealth", hp2, 1);
			}
		}
	}
}
public VamPire(int Client, float damage)
{
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("뱀파이어");
		if(skillid == 0) return;
		if(PlayerSkill[Client][skillid] < 1) return;

		int Random = GetRandomInt(0, 100);
		if(Random < 5 + PlayerSkill[Client][skillid])
		{
			int maxhp = GetClientMaxHealth(Client);
			int hp = GetClientHealth(Client);
			if(maxhp > hp)
			{
				int vampire = FloatToInt(damage * (PlayerSkill[Client][skillid] * VampireIndex));
				if(vampire <= 0) vampire = 1;
				
				int hp2 = hp + vampire;
				if(hp2 >= maxhp) hp2 = maxhp;
				
				SetEntProp(Client, Prop_Data, "m_iHealth", hp2, 1);
				PrintToChat(Client, "\x07FF0000[뱀파이어] \x03- %d\x07FF0000HP \x07FFFF48회복", vampire);
				Sound("ambient/machines/machine1_hit2.wav", _, Client);
			}
		}
	}
}
public float StickDamage(int Client)
{
	float dmg = 1.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("근접무기 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		dmg = 1.0 + (PlayerSkill[Client][skillid] * StickIndex);
	}
	
	return dmg;
}
public float RifleDamage(int Client, const char[] Name) //+
{
	float dmg = 0.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("라이플 탄환 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "weapon_smg1", false) 
		|| StrEqual(Name, "weapon_ar2", false) 
		|| StrEqual(Name, "weapon_mg1", false)
		|| StrEqual(Name, "weapon_mp5k", false))
			dmg = (PlayerSkill[Client][skillid] * RifleIndex);
	}
	return dmg;
}
public float PistolDamage(int Client, const char[] Name) //+
{
	float dmg = 0.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("피스톨 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "weapon_pistol", false))
			dmg = (PlayerSkill[Client][skillid] * PistolIndex);
	}
	return dmg;
}
public float MagnumDamage(int Client, const char[] Name) //*
{
	float dmg = 1.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("357/매그넘 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "weapon_357", false) || StrEqual(Name, "weapon_degle", false))
			dmg = 1.0 + (PlayerSkill[Client][skillid] * MagnumIndex);
	}
	return dmg;
}
public float ShotgunDamage(int Client, const char[] Name) //+
{
	float dmg = 0.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("샷건 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "weapon_shotgun", false))
			dmg = (PlayerSkill[Client][skillid] * ShotgunIndex);
	}
	return dmg;
}
public float CrossbowDamage(int Client, const char[] Name) //+
{
	float dmg = 0.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("석궁 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "weapon_crossbow", false))
		{
			dmg = (PlayerSkill[Client][skillid] * CrossbowIndex);
		}
	}
	return dmg;
}
public float ExplosiveDamage(int Client, const char[] Name) //*, Inf
{
	float dmg = 1.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("폭탄 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;
		
		if(StrEqual(Name, "grenade_ar2", false) 
		|| StrEqual(Name, "npc_grenade_frag", false)
		|| StrEqual(Name, "rpg_missile", false)
		|| StrEqual(Name, "npc_tripmine", false)
		|| StrEqual(Name, "npc_satchel", false))
			dmg = 1.0 + (PlayerSkill[Client][skillid] * ExplosiveIndex);
	}
	return dmg;
}
public float HeadShot(int Client) //*
{
	float dmg = 1.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("헤드샷 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;

		dmg = 1.0 + (PlayerSkill[Client][skillid] * HeadShotIndex);
	}
	return dmg;
}
public float BodyShot(int Client) //*
{
	float dmg = 1.0;
	if(IsClientConnectedIngameAlive(Client))
	{
		int skillid = FindSkillIdByName("바디샷 강화");
		if(skillid == 0) return dmg;
		if(PlayerSkill[Client][skillid] < 1) return dmg;

		dmg = 1.0 + (PlayerSkill[Client][skillid] * BodyShotIndex);
	}
	return dmg;
}
//메뉴
public LearnSkill(int Client, int page)
{
	char s_Name[256], s_Jop[32];
	Menu menu = new Menu(SkillMenu_Handler, MENU_ACTIONS_ALL);
	Format(s_Name, sizeof(s_Name), "▬▬▬▬ 스킬 ▬▬▬▬\nAP : %d\n ", PlayerData[Client][g_iSkp]);
	menu.SetTitle(s_Name);
	
	for(int i = 1; i < MAX_SKILL; i++)
	{
		Format(s_Name, sizeof(s_Name), "%s : %d/%d\n - %s%s", Skill[i].Name, PlayerSkill[Client][i], Skill[i].Max, Skill[i].Description, i % 7 == 0 ? "\n\n " : "");
		IntToString(i, s_Jop, sizeof(s_Jop));
		
		if(PlayerData[Client][g_iSkp] > 0)
		{
			if(Skill[i].Max > PlayerSkill[Client][i]) menu.AddItem(s_Jop, s_Name);
			else
			{
				Format(s_Name, sizeof(s_Name), "%s : %d/%d[MAX]\n - %s", Skill[i].Name, PlayerSkill[Client][i], Skill[i].Max,Skill[i].Description);
				menu.AddItem(s_Jop, s_Name, ITEMDRAW_DISABLED);	
			}
		}
		else
		{
			Format(s_Name, sizeof(s_Name), "%s : %d/%d[X]\n - %s", Skill[i].Name, PlayerSkill[Client][i], Skill[i].Max, Skill[i].Description);
			menu.AddItem(s_Jop, s_Name, ITEMDRAW_DISABLED);
		}
	}
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	if(page == 0) menu.Display(Client, MENU_TIME_FOREVER);
	else menu.DisplayAt(Client, page, MENU_TIME_FOREVER);
}
public int SkillMenu_Handler(Menu menu, MenuAction action, int Client, int Select)
{
	switch(action)
	{
		case MenuAction_Start:
		{
			//
		}
		case MenuAction_Select:
		{
			char Menus[256]; int s_Stet;
			menu.GetItem(Select, Menus, sizeof(Menus));
			s_Stet = StringToInt(Menus);
			
			if(PlayerData[Client][g_iSkp] > 0)
			{
				if(Skill[s_Stet].Max > PlayerSkill[Client][s_Stet])
				{
					PlayerData[Client][g_iSkp]--;
					PlayerSkill[Client][s_Stet]++;
					SkillSave(Client, s_Stet);
					PrintToChat(Client, "%s : %d/%d", Skill[s_Stet].Name, PlayerSkill[Client][s_Stet], Skill[s_Stet].Max);
				}
				else //최대인경우
				{
					PrintToChat(Client, " \x06최대 레벨입니다.");
					Sound("buttons/button10.wav", _, Client, true);
				}
			}
			else PrintToChat(Client, "\x06AP가 부족합니다.");
			
			LearnSkill(Client, GetMenuSelectionPosition());
		}
	 
		case MenuAction_Cancel:
		{
			//if(Select == MenuCancel_ExitBack) F3MainMenu(Client);
			//PrintToServer("Client %d's menu was cancelled for reason %d", Client, Select);
		}
		case MenuAction_End: delete menu;
	}
	return 0;
}

//스톡
stock bool:IsClientConnectedIngame(client){
	if(client > 0 && client <= MaxClients){
		if(IsClientConnected(client) == true){
			if(IsClientInGame(client) == true){
				return true;
			}else{
				return false;
			}
		}else{
			return false;
		}
	}else{
		return false;
	}
}
stock bool:IsClientConnectedIngameAlive(client)
{
	if(IsClientConnectedIngame(client)){
	
		if(IsPlayerAlive(client) == true && IsClientObserver(client) == false){
					
			return true;
		
		}else{
		
			return false;
	
		}
		
	}else{
		
		return false;
	
	}
}
stock bool:IsClientAlive(Client)
{
	if(Client > 0 && Client <= MaxClients)
	{
		if(IsClientInGame(Client))
		{
			if(IsPlayerAlive(Client))
			{
				return true;
			}
		}
	}
	return false;
}
public bool:AliveCheck(Client)
{
	if(Client > 0 && Client <= MaxClients)
		if(IsClientConnected(Client) == true)
			if(IsClientInGame(Client) == true)
				if(IsPlayerAlive(Client) == true) return true;
				else return false;
			else return false;
		else return false;
	else return false;
}
stock bool:IsPlayerWithin(Client, Entity, Data)
{
  decl Float:ClientOrigin[3];
  decl Float:EntityOrigin[3];
  
  GetEntPropVector(Client, Prop_Send, "m_vecOrigin", ClientOrigin);
  GetEntPropVector(Entity, Prop_Send, "m_vecOrigin", EntityOrigin);
  
  decl Float:DistanceOrigin;
  DistanceOrigin = GetVectorDistance(ClientOrigin, EntityOrigin);
  
  if(DistanceOrigin <= Data)
  {
    return true;
  } 
  
  return false;
}

stock Float:IntToFloat(i_Int)
{
	decl String:s_Int[256];
	Format(s_Int, sizeof(s_Int), "%d.0", i_Int);
	return StringToFloat(s_Int);
}
stock FloatToInt(Float:f_Float)
{
	decl String:s_Float[256];
	FloatToString(f_Float, s_Float, sizeof(s_Float));
	return StringToInt(s_Float);
}

stock sendKeyHintTextMsg(client, String:msg[], any:...)
{
	new Handle:hudhandle = INVALID_HANDLE;
	hudhandle = StartMessageOne("KeyHintText", client);
	
	if(hudhandle != INVALID_HANDLE)
	{
		new String:txt[255];
		VFormat(txt, sizeof(txt), msg, 3);
		BfWriteByte(hudhandle, 1);
		BfWriteString(hudhandle, txt);
		EndMessage();
	}
}
stock sendHintTextMsg(client, String:msg[], any:...){
	//it was same as PrintHintText, but it made differant effect at hl2mp, it can print short single line msg
	new Handle:hudhandle = INVALID_HANDLE;
	
	if (client == 0){
		
		hudhandle = StartMessageAll("HintText");
		
	}else{
		
		hudhandle = StartMessageOne("HintText", client);
		
	}
	
	new String:txt[512];
	VFormat(txt, sizeof(txt), msg, 3);	
	
	if (hudhandle != INVALID_HANDLE) { 
		
		BfWriteByte(hudhandle, 1);
		BfWriteString(hudhandle, txt);
		EndMessage(); 
		
	}
	
}
/** 사운드스톡:파천지교
 * 사운드를 보다 편리하게 출력시키도록 도와주는 함수
 *
 * @param Path      사운드의 경로
 * @param Vol			사운드의 볼륨 크기
 * @param Client			특정 클라이언트
 * @param Origin      클라이언트 주변 설정
 * @error				유효하지 않는 클라이언트
 */
stock Sound(const String:Path_[], Float:Vol=1.0, Client=0, bool:Origin=false)
{
	//To All (Volume : 1.0)
	//Sound("sound/test.mp3");
	
	//To All (Volume : 1.5)
	//Sound("sound/test.mp3", 1.5);
	
	//To Client (Volume : 1.0)
	//Sound("sound/test.mp3", _, Client);
	
	//To Client and Near of Client (Volume : 1.0)
	//Sound("ambient/energy/whiteflash.wav", _, Client, true);
	PrecacheSound(Path_, true);

	if(Client == 0)
	{
		EmitSoundToAll(Path_, SOUND_FROM_PLAYER, _, _, _, Vol);
	}
	else
	{
		if(Origin)
		{
			if(IsClientConnected(Client) && IsPlayerAlive(Client))
			{
				decl Float:ClientOrigin[3];
				GetClientAbsOrigin(Client, ClientOrigin);

				EmitSoundToAll(Path_, SOUND_FROM_WORLD, _, _, _, Vol, _, _, ClientOrigin);
			}
		}
		else
		{
			EmitSoundToClient(Client, Path_, SOUND_FROM_PLAYER, _, _, _, Vol);
		}
	}
}

//사운드재생중지
stock void StopSoundPermAny(int i, char[] sound)
{
	StopSound(i, SNDCHAN_AUTO, sound);
	StopSound(i, SNDCHAN_WEAPON, sound);
	StopSound(i, SNDCHAN_VOICE, sound);
	StopSound(i, SNDCHAN_ITEM, sound);
	StopSound(i, SNDCHAN_BODY, sound);
	StopSound(i, SNDCHAN_STREAM, sound);
	StopSound(i, SNDCHAN_VOICE_BASE, sound);
	StopSound(i, SNDCHAN_USER_BASE, sound);
	
	ClientCommand(i, "playgamesound Music.StopAllExceptMusic");
	ClientCommand(i, "playgamesound Music.StopAllMusic");
}
public SetClientMaxHealth(client, value)
{
	SetEntProp(client, Prop_Data, "m_iMaxHealth", value);
}
public GetClientMaxHealth(client)
{
	return GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

stock SayText2ToAll(client, const String:message[], any:...)
{
	new Handle:buffer = INVALID_HANDLE;
	new String:txt[255];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(txt, sizeof(txt), message, 3);
			
			buffer = StartMessageOne("SayText2", i);
			
			if (buffer != INVALID_HANDLE)
			{
				BfWriteByte(buffer, client);
				BfWriteByte(buffer, true);
				BfWriteString(buffer, txt);
				EndMessage();
				buffer = INVALID_HANDLE;
			}
		}
	}
}

public int GetIntByFeildName(Handle handle, const char[] FieldName) //, int Variable
{
	int Field = 0;
	if(handle != INVALID_HANDLE)
	{
		SQL_FieldNameToNum(handle, FieldName, Field);	
		//Variable = SQL_FetchInt(handle, Field);
	}
	return (SQL_FetchInt(handle, Field));
}


//스톡:생성
stock CreateNpc(num, const char s_Name[256], const char s_Class[256], s_Dollar)
{
	if(MAX_NPC <= num) MAX_NPC = num + 1;
	NPC[num].Name = s_Name;
	NPC[num].Class = s_Class;
	NPC[num].Dollar = s_Dollar;
}
//번호 이름 설명 효과량 최대치 필요량
stock CreateSkill(num, const char name[256], const char descrip[256], effect, max, need)
{
	if(MAX_SKILL <= num) MAX_SKILL = num + 1;
	Skill[num].Name = name;
	Skill[num].Description = descrip;
	Skill[num].Effect = effect;
	Skill[num].Max = max;
	Skill[num].Need = need;
}

public int GetHp2(int Client)
{
	int index = 0;
	for(int i = 0; i <= PlayerData[Client][g_iLevel]; i++)
	{
		if(i%LvHp2 == 0)
		{
			index++ 
		}
	}		
	return index;
}
stock int FindSkillIdByName(const char[] iString)
{
	int index = 0;
	for(int i = 1; i <= MAX_SKILL; i++)
	{
		if(StrEqual(Skill[i].Name, iString, false))
		{
			index = i;
			break;
		}
	}
	return index;
}