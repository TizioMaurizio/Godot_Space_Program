"""Generate a small reusable standardized catalog and AORS recipes (SI units)."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
Q = [0, 0, 0, 1]


def node(position, normal, size, capacity=1):
    return dict(position=position, normal=normal, size=size, capacity=capacity)


def cylinder_nodes(length, radius):
    result = {
        "top": node([0, length / 2, 0], [0, 1, 0], radius),
        "bottom": node([0, -length / 2, 0], [0, -1, 0], radius),
        "radial": node([radius, 0, 0], [1, 0, 0], 0, 8),
        "surface": node([-radius, 0, 0], [-1, 0, 0], 0),
    }
    for name, p, n in [("dock_top", [0,length/2,0],[0,1,0]),("dock_bottom",[0,-length/2,0],[0,-1,0]),("dock_port",[-radius,0,0],[-1,0,0]),("dock_starboard",[radius,0,0],[1,0,0]),("dock_zenith",[0,0,radius],[0,0,1]),("dock_nadir",[0,0,-radius],[0,0,-1])]:
        result[name] = node(p,n,0.6)
    return result


def rotate(q, p):
    x,y,z,w = q; px,py,pz = p
    tx,ty,tz = 2*(y*pz-z*py),2*(z*px-x*pz),2*(x*py-y*px)
    return [px+w*tx+y*tz-z*ty,py+w*ty+z*tx-x*tz,pz+w*tz+x*ty-y*tx]


def write(path, data):
    path = ROOT / path; path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")


def generate():
    new = []
    for size, diameter, length, mass in [("S",1.2,2,800),("M",2,4,2500),("X",3,6,9000),("XL",4,8,13500)]:
        new.append(dict(id=f"container.{size.lower()}",display_name=f"{size} Multipurpose Container",category="Containers",size_class=size,dry_mass=mass,length=length,radius=diameter/2,visual="habitat",nodes=cylinder_nodes(length,diameter/2),modules={"electric_load":{"critical_w":200 if size=="S" else 0,"optional_w":6000 if size=="XL" else 3000}},description="Reusable pressurized/cargo shell; contents, crew, EVA and thermal simulation are not modeled."))
    hub_nodes = cylinder_nodes(6,2)
    for name,p,n in [("port",[-2,0,0],[-1,0,0]),("starboard",[2,0,0],[1,0,0]),("zenith",[0,0,2],[0,0,1]),("nadir",[0,0,-2],[0,0,-1])]: hub_nodes[name]=node(p,n,2)
    hub_nodes["port_x"]=node([-2,0,0],[-1,0,0],1.5)
    hub_nodes["starboard_x"]=node([2,0,0],[1,0,0],1.5)
    hub_nodes["zenith_m"]=node([0,0,2],[0,0,1],1)
    new.append(dict(id="structure.node.xl",display_name="XL Six-way Node",category="Structural",size_class="XL",dry_mass=13500,length=6,radius=2,visual="node",nodes=hub_nodes,modules={"command":{},"wheel":{"torque":2000000},"battery":{"capacity_j":120000000},"electric_load":{"critical_w":1500,"optional_w":1000}}))
    truss_nodes = cylinder_nodes(12,1.5)
    truss_nodes.update({"keel":node([0,0,-1.5],[0,0,-1],1),"wing_front":node([-1.5,0,1],[-1,0,0],1),"wing_aft":node([1.5,0,1],[1,0,0],1),"radiator_front":node([-1.5,0,-1],[-1,0,0],1),"radiator_aft":node([1.5,0,-1],[1,0,0],1)})
    new.append(dict(id="structure.truss.x",display_name="X Lattice Truss / 12 m",category="Structural",size_class="X",dry_mass=8000,length=12,radius=1.5,box_size=[3,12,3],visual="truss",nodes=truss_nodes,bending_strength=4000000))
    for id,title,visual,length,width,depth,mass,module in [("power.solar.xl","XL Solar Wing","solar",34,11,0.3,1500,{"solar":{"power_w":18000,"normal":[0,0,1]}}),("power.radiator.x","X Radiator Panel","radiator",10,3,0.2,600,{})]:
        nodes={"top":node([0,length/2,0],[0,1,0],1),"bottom":node([0,-length/2,0],[0,-1,0],1)}
        new.append(dict(id=id,display_name=title,category="Power",size_class="XL" if visual=="solar" else "X",dry_mass=mass,length=length,radius=width/2,box_size=[width,length,depth],visual=visual,nodes=nodes,modules=module,strength=20000,bending_strength=20000,crash_speed=3,description="Fixed deployed wing; solar generation is functional." if visual=="solar" else "Physical radiator; thermal simulation is deferred."))
    new.append(dict(id="docking.port.s",display_name="S Docking Port / 1.2 m",category="Docking",size_class="S",dry_mass=250,length=0.8,radius=0.6,visual="docking",nodes={"bottom":node([0,-0.4,0],[0,-1,0],0.6),"dock":node([0,0.4,0],[0,1,0],0.6)},modules={"docking":{"type":"S","distance":0.12,"lateral":0.1,"speed":0.25,"angle_deg":7.5}},strength=150000,bending_strength=250000,crash_speed=4))
    new.append(dict(id="utility.rcs.s",display_name="S RCS Block",category="Utility",size_class="S",dry_mass=60,length=0.8,radius=0.4,box_size=[0.8,0.8,0.8],visual="rcs",nodes={"surface":node([-0.4,0,0],[-1,0,0],0),"top":node([0,0.4,0],[0,1,0],0.6),"bottom":node([0,-0.4,0],[0,-1,0],0.6)},modules={"rcs":{"thrust":1000,"isp":240,"propellant":100}}))
    write("data/parts/standard_parts.json",new)
    existing=json.loads((ROOT/"data/parts/catalog.json").read_text(encoding="utf-8"))
    # Existing default sockets match PartDefinition's generated nodes.
    for part in existing:
        if "nodes" not in part: part["nodes"]=cylinder_nodes(part["length"],part["radius"])
        if part.get("visual")=="capsule" and "command" in part.get("modules",{}): part["nodes"]["top"]["size"]=0.5
        for name,offset in [("radial_low",-0.35),("radial_high",0.35)]: part["nodes"][name]=node([part["radius"],part["length"]*offset,0],[1,0,0],0,8)
    catalog={p["id"]:p for p in existing+new}

    def recipe(name): return dict(schema_version=1,catalog_version=1,name=name,root_part_id="",parts=[],connections=[],stages=[],symmetry_groups=[],aero_model="parts")
    def add(craft,id,definition,parent=None,parent_port="top",child_port="bottom",q=Q,settings=None,ratings=None):
        position=[0,0,0]
        if parent:
            pe=next(p for p in craft["parts"] if p["id"]==parent)
            pn=catalog[pe["definition_id"]]["nodes"][parent_port]
            cn=catalog[definition]["nodes"][child_port]
            a=rotate(pe["rotation_xyzw"],pn["position"]); b=rotate(q,cn["position"])
            position=[pe["position_m"][i]+a[i]-b[i] for i in range(3)]
            edge=dict(id=f"joint_{len(craft['connections'])+1}",a=[parent,parent_port],b=[id,child_port],crossfeed=True)
            if ratings: edge.update(ratings)
            craft["connections"].append(edge)
        else: craft["root_part_id"]=id
        craft["parts"].append(dict(id=id,definition_id=definition,position_m=position,rotation_xyzw=q,settings=settings or {}))
    z90=[0,0,math.sqrt(.5),math.sqrt(.5)]; zneg=[0,0,-math.sqrt(.5),math.sqrt(.5)]; x90=[math.sqrt(.5),0,0,math.sqrt(.5)]; xneg=[-math.sqrt(.5),0,0,math.sqrt(.5)]
    station=recipe("Aster Orbital Research Station / AORS")
    add(station,"aors-core","structure.node.xl")
    add(station,"aors-lab-axial","container.xl","aors-core")
    add(station,"aors-node-forward","structure.node.xl","aors-lab-axial")
    add(station,"aors-lab-port","container.x","aors-node-forward","port_x",q=z90)
    add(station,"aors-lab-starboard","container.xl","aors-node-forward","starboard",q=zneg)
    add(station,"aors-hab-node","structure.node.xl","aors-core","bottom","top")
    add(station,"aors-service","container.xl","aors-hab-node","bottom","top")
    add(station,"aors-airlock","container.x","aors-core","port_x",q=z90)
    add(station,"aors-logistics","container.x","aors-hab-node","starboard_x",q=zneg)
    add(station,"aors-observation","container.s","aors-hab-node","dock_nadir",q=xneg)
    add(station,"aors-keel","container.m","aors-core","zenith_m",q=x90,settings={"electric_load_w":0})
    truss_ratings=dict(strength=1500000,shear_strength=800000,bending_strength=4000000,torsion_strength=1500000)
    add(station,"truss-center","structure.truss.x","aors-keel","top","keel",q=zneg,ratings=truss_ratings)
    for side,count,port,child in [("port",3,"bottom","top"),("starboard",4,"top","bottom")]:
        parent="truss-center"
        for i in range(1,count+1):
            id=f"truss-{side}-{i}"; add(station,id,"structure.truss.x",parent,port,child,q=zneg,ratings=truss_ratings); parent=id
    weak=dict(strength=20000,shear_strength=8000,bending_strength=20000,torsion_strength=15000)
    for parent in ["truss-port-1","truss-port-3","truss-starboard-1","truss-starboard-3"]:
        add(station,parent+"-solar-front","power.solar.xl",parent,"wing_front","bottom",ratings=weak)
        add(station,parent+"-solar-aft","power.solar.xl",parent,"wing_aft","top",ratings=weak)
    for parent in ["truss-port-2","truss-center","truss-starboard-2"]:
        add(station,parent+"-radiator-front","power.radiator.x",parent,"radiator_front","bottom",ratings=weak)
        add(station,parent+"-radiator-aft","power.radiator.x",parent,"radiator_aft","top",ratings=weak)
    for id,parent,port,q in [("dock-forward","aors-node-forward","dock_top",Q),("dock-zenith","aors-node-forward","dock_zenith",x90),("dock-nadir","aors-node-forward","dock_nadir",xneg),("dock-aft","aors-service","dock_bottom",[0,0,1,0]),("dock-service","aors-service","dock_port",z90)]:
        add(station,id,"docking.port.s",parent,port,q=q)
    # Four reusable RCS blocks attached to unused service sockets.
    for i,(parent,port,q) in enumerate([("aors-service","dock_starboard",zneg),("aors-service","dock_zenith",x90),("aors-service","dock_nadir",xneg),("aors-core","dock_starboard",zneg)]):
        add(station,f"rcs-{i}","utility.rcs.s",parent,port,q=q)
    add(station,"service-tank","tank.small","aors-hab-node","dock_port",q=z90,settings={"fuel_fill":1,"oxidizer_fill":1})
    add(station,"service-engine","engine.mote","service-tank",q=z90)
    # Side laboratories use a 3 m standardized neck on a 4 m hub; socket size is stated.
    write("data/craft/aors_complete.json",station)
    visitor=recipe("S Orbital Docking Tug")
    add(visitor,"tug-core","command.probe",settings={"battery_capacity_j":2000000,"electric_load_w":100})
    add(visitor,"tug-dock","docking.port.s","tug-core")
    add(visitor,"tug-tank","tank.small","tug-core","bottom","top")
    add(visitor,"tug-engine","engine.mote","tug-tank","bottom","top")
    add(visitor,"tug-rcs","utility.rcs.s","tug-core","radial","surface")
    add(visitor,"tug-rcs-opposite","utility.rcs.s","tug-core","radial","surface",q=[0,1,0,0])
    visitor["parts"][-1]["position_m"]=[-1,0,0]
    visitor["connections"][-1]["radial_angle"]=math.pi
    visitor["stages"]=[dict(id="engine",actions=[dict(part_id="tug-engine",action="ignite")])]
    write("data/craft/docking_tug.json",visitor)
    for name,with_tug in [("aors_complete_orbit",False),("aors_docking_test",True)]:
        write(f"data/scenarios/{name}.json",dict(schema_version=1,type="initialized_orbital_scenario",label="PREBUILT / INITIALIZED FOR PLAYTESTING",station="res://data/craft/aors_complete.json",altitude_m=120000,inclination_deg=51.6,raan_deg=25,argument_of_latitude_deg=0,visitor="res://data/craft/docking_tug.json" if with_tug else "",visitor_distance_m=650))
    # A physically launchable module carrier using the existing capsule/tanks/engines.
    cargo=recipe("X Module Launcher / three Forge boosters")
    add(cargo,"capsule","command.capsule")
    add(cargo,"dock","docking.port.s","capsule")
    add(cargo,"module","container.x","capsule","bottom","top")
    add(cargo,"upper-tank","tank.lumen","module","bottom","top")
    add(cargo,"upper-engine","engine.lumen","upper-tank","bottom","top")
    add(cargo,"interstage","decoupler.stack","upper-engine","bottom","top")
    add(cargo,"booster-tank","tank.forge","interstage","bottom","top")
    add(cargo,"booster-engine","engine.forge","booster-tank","bottom","top")
    # Balanced radial branches: direct saved socket frame uses a radial angle.
    for index,angle in enumerate([0,math.pi]):
        id=f"radial-{index}"; q=[0,math.sin(angle/2),0,math.cos(angle/2)]
        add(cargo,id,"decoupler.radial","booster-tank","radial_high","surface",q=q)
        cargo["connections"][-1]["radial_angle"]=angle
        parent=next(p for p in cargo["parts"] if p["id"]=="booster-tank")
        mount=rotate(q,catalog["tank.forge"]["nodes"]["radial_high"]["position"])
        dock=rotate(q,catalog["decoupler.radial"]["nodes"]["surface"]["position"])
        cargo["parts"][-1]["position_m"]=[parent["position_m"][i]+mount[i]-dock[i] for i in range(3)]
        add(cargo,id+"-tank","tank.forge",id,"radial","surface",q=q)
        add(cargo,id+"-engine","engine.forge",id+"-tank","bottom","top",q=q)
    cargo["stages"]=[dict(id="launch",actions=[dict(part_id=id,action="ignite") for id in ["booster-engine","radial-0-engine","radial-1-engine"]]),dict(id="upper",actions=[dict(part_id=id,action="shutdown") for id in ["booster-engine","radial-0-engine","radial-1-engine"]]+[dict(part_id="interstage",action="decouple"),dict(part_id="upper-engine",action="ignite")])]
    write("data/craft/module_launcher.json",cargo)
    mass=sum(catalog[p["definition_id"]]["dry_mass"]+catalog[p["definition_id"]].get("modules",{}).get("rcs",{}).get("propellant",0)+sum(catalog[p["definition_id"]].get("modules",{}).get("tank",{}).values()) for p in station["parts"])
    print(f"AORS: {len(station['parts'])} parts, {mass:,.0f} kg; {len(new)} reusable new definitions")


if __name__=="__main__": generate()
