using System.Text.Json;
using UnityEngine;
using HybridLumenGI;
using L=HybridLumenGI.HybridLumenGILights;
var light=new Light{type=LightType.Point,range=1};
light.transform.position=new Vector3(100,0,0);
UnityEngine.Object.Found=new[]{light};
var collector=new L();var data=new L.Data[32];var changes=new List<L.Data>();int count=0,frame=0;
var events=new Dictionary<string,L.Data[]>();
void Capture(string name){count=collector.Update(++frame,false,data,32,count,changes,out _);events[name]=changes.ToArray();}
Capture("initial");
light.transform.position=new Vector3(300,0,0);Capture("move");
light.isActiveAndEnabled=false;Capture("off");
light.isActiveAndEnabled=true;light.type=LightType.Directional;Capture("directional");
if(events["initial"].Length!=1 || events["initial"][0].positionType.x!=100 ||
   events["move"].Length!=2 || events["move"][0].positionType.x!=100 || events["move"][1].positionType.x!=300 ||
   events["off"].Length!=1 || events["off"][0].positionType.x!=300 ||
   events["directional"].Length!=1 || events["directional"][0].positionType.w>=.5f)throw new Exception("Unexpected actual light events");
File.WriteAllText(args[0],JsonSerializer.Serialize(events,new JsonSerializerOptions{IncludeFields=true,WriteIndented=true}));
Console.WriteLine("PASS: actual unchanged light collector emitted initial, old/new movement, disabled old-position and directional records; Unity discovery/components are explicit existing adapters.");
