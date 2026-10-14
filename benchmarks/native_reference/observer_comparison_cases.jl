function run_comparison(label;dtmax=0.025,targeting=false,two_pass=false,target_radius=19800e3,select_reachable=false)
    planet=SM.Mars(Rp_e=3396200.0,Rp_p=3376200.0,Rp_m=3389500.0,μ=4.282837362069909e13)
    alpha=planet.α;delta=planet.δ
    # Exact legacy PCI to current J2000 adapter. No initial-state optimization.
    P=@SMatrix [-sin(alpha) cos(alpha) 0.0; -sin(delta)*cos(alpha) -sin(delta)*sin(alpha) cos(delta); cos(delta)*cos(alpha) cos(delta)*sin(alpha) sin(delta)]
    r_old=SVector(3410778.945454985,63201.87611889155,-1004565.0541881445)
    v_old=SVector(759.2524339373954,-279.85539959166766,4448.174198607619)
    if two_pass
        rp=planet.Rp_e+100e3; ra=20000e3; a=(ra+rp)/2; ecc=(ra-rp)/(ra+rp); sl=a*(1-ecc^2)
        nu=pi; inc=deg2rad(93.6)
        r_old=SVector(sl/(1+ecc*cos(nu))*cos(nu),sl/(1+ecc*cos(nu))*sin(nu)*cos(inc),sl/(1+ecc*cos(nu))*sin(nu)*sin(inc))
        v_old=sqrt(planet.μ/sl)*SVector(-sin(nu),(ecc+cos(nu))*cos(inc),(ecc+cos(nu))*sin(inc))
    end
    r=P'*r_old;v=P'*v_old
    a0=(20000e3+planet.Rp_e+100e3)/2
    period=2pi*sqrt(a0^3/planet.μ)
    duration=two_pass ? ceil(2period) : ceil(period)

    original=_edg_test_context()
    craft=original.spacecraft
    craft.initial_condition=SM.CartesianInitialCondition(r,v)
    for link in craft.links;link.α=pi/2;end
    config=SM.AerobrakingEnergyDepletionConfig(guidance_modes=targeting ? (:targeting,:max_energy_depletion) : (:max_energy_depletion,),target_apoapsis_radius_m=target_radius,max_energy_submodes=(:heat_rate,:structural_load,:heat_load),heat_load_switch_solver=:closed_form,controlled_panel_links=(2,3),max_alpha_rad=pi/2,min_alpha_rad=0.0,heat_rate_limit_w_cm2=0.15,heat_load_limit_j_cm2=30.0,structural_load_limit_pa=0.5)
    state=SM.AerobrakingEnergyDepletionState(num_sats=1)
    guidance=SM.AerobrakingEnergyDepletionGuidanceModel(config,state)
    control=SM.AerobrakingEnergyDepletionControlModel(config,state)
    args=SM.SimulationConfiguration(
        simulation_settings=SM.SimulationSettings(results=false,verbose=false,generate_plots=false,save_csv=false,results_directory=joinpath(ROOT,label)),
        mission_configuration=SM.MissionConfiguration(mission_type=SM.MissionTime,mission_time=duration,orientation_sim=false,keplerian=false,data_rate=0.1),
        environment_model=SM.EnvironmentModel(planet=planet,EI=160.0,density_model=NativeComparisonAtmosphere(),ephemerides_model=SM.SpiceEphemeridesModel(),thermal_model=SM.MaxwellianHeat(thermal_accomodation_factor=1.0,planet=planet),wind=false,topography=false),
        dynamics_model=SM.DynamicsModel([craft],(SM.InverseSquaredJ2GravityModel(),SM.AerodynamicCoefficientfM())),
        guidance_model=SM.GuidanceModel((guidance,),[1/3]),control_model=SM.ControlModel((control,),[1/3]),
        navigation_model=SM.NavigationModel((),Float64[]),initial_time=SM.InitialTime(year=2001,month=11,day=6,hour=19,minute=0,second=0.0),
        integration_tolerances=SM.IntegrationTolerances(reltol_orbit=1e-10,abstol_orbit=1e-10,dt_max_orbit=20.0,reltol_atmosphere=1e-10,abstol_atmosphere=1e-10,dt_max_atmosphere=dtmax),
        solver_config=SM.SolverConfig(solver_mode=:tsit5,maxiters=2_000_000))
    selection=Dict{String,Any}()
    if select_reachable
        # Define the target once from an evaluated eight-second switch at the
        # retained three-second state, before observing this run's terminal result.
        lines=readlines(joinpath(ROOT,"..","baseline","gram_depletion.csv"))
        source_rows=[parse.(Float64,split(line,',')) for line in lines[2:end]]
        row=source_rows[argmin(abs(row[1]-3.0) for row in source_rows)]
        @assert abs(row[1]-3.0)<1e-10
        rr=P'*SVector{3,Float64}(row[2:4]);vv=P'*SVector{3,Float64}(row[5:7])
        pre=SM.ODEParams(n_sats=1,args=args)
        pre.shared_buffers.et_start[]=SM.ephemerides_time_seconds(args.initial_time,args.environment_model.ephemerides_model)
        prediction=CH._edg_predict_targeting_outcome(config,pre,craft,rr,vv,461.0,3.0,8.0;heat_rate_control=true,structural_control=true)
        certificate=CH._edg_targeting_candidate_certificate(config,pre,craft,461.0,3.0,prediction;heat_load_j_cm2=max(row[17],row[18]),heat_rate_control=true,structural_control=true)
        @assert certificate.heat_feasible && certificate.instantaneous_admissible
        coast=CH._edg_vacuum_apoapsis_correction(pre,prediction.exit_position,prediction.exit_velocity,461.0,3.0+prediction.duration_s)
        @assert coast.event_reached
        target_radius=norm(coast.position)
        fields=(;(k=>getfield(config,k) for k in fieldnames(typeof(config)))...)
        config=SM.AerobrakingEnergyDepletionConfig(;merge(fields,(target_apoapsis_radius_m=target_radius,))...)
        guidance=SM.AerobrakingEnergyDepletionGuidanceModel(config,state);control=SM.AerobrakingEnergyDepletionControlModel(config,state)
        afields=(;(k=>getfield(args,k) for k in fieldnames(typeof(args)))...)
        args=SM.SimulationConfiguration(;merge(afields,(guidance_model=SM.GuidanceModel((guidance,),[1/3]),control_model=SM.ControlModel((control,),[1/3])))...)
        selection=Dict("rule"=>"Predictor-defined target at evaluated switch 8 s, using retained depletion state at t=3 s before full targeting execution; no post-result target adjustment", "reference_time_s"=>3.0,"reference_switch_s"=>8.0,"target_radius_m"=>target_radius,"predicted_heat_load_j_cm2"=>certificate.heat_load_j_cm2,"reference_state_pci"=>row[2:7])
        save_result(label*"_target_selection",selection)
        println("TARGET_FIXED ",selection);flush(stdout)
    end
    empty!(native_cache)
    native_start=native_calls[];requests_start=native_requests[];hits_start=native_cache_hits[];checked_start=native_checked_hits[]
    planning_records=Dict[];last_plan_count=Ref(0)
    rows=Vector{Vector{Float64}}();boundaries=Dict[];apoapses=Dict[];passage_records=Dict[];seen_exits=Set{Tuple}();last_coast=Ref(-Inf);last_progress=Ref(-Inf);last_observed=Ref(0.0)
    function observe(u,t,integrator)
        last_observed[]=Float64(t)
        if t-last_progress[]>=1000.0
            println("PROGRESS ",label," t=",t," rows=",length(rows)," boundaries=",length(boundaries));flush(stdout);last_progress[]=Float64(t)
        end
        p=integrator.p;sc=u.sc[1];c=p.args.dynamics_model.spacecraft[1];st=p.args.control_model.control_effectors[1].state
        if st.energy_bracketing_count[1] != last_plan_count[]
            plan=st.targeting_diagnostics[1]
            record=Dict{String,Any}("time_s"=>Float64(t),"count"=>st.energy_bracketing_count[1],"last_solve_time_s"=>st.last_switch_solve_t[1],"actual_pass_heat_j_cm2"=>CH._edg_pass_heat_load_for_links(sc,(2,3),st,1),"applied_alpha_rad"=>c.links[2].α)
            for (key,value) in pairs(plan)
                record[string(key)]=value isa Symbol ? String(value) : value isa NamedTuple ? Dict(string(k)=>(v isa Symbol ? String(v) : v) for (k,v) in pairs(value)) : value
            end
            push!(planning_records,record);last_plan_count[]=st.energy_bracketing_count[1]
            println("PLAN_RECORD ",label," ",record);flush(stdout)
        end
        R=SVector{3,Float64}(sc.pos);V=SVector{3,Float64}(sc.vel)
        # Observe native accepted spherical events without adding a duplicate root.
        if abs(norm(R)-planet.Rp_e-160000)<1e-4
            kind=dot(R,V)<0 ? "entry" : "exit"
            if isempty(boundaries) || abs(Float64(t)-boundaries[end]["time_s"])>1e-5 || boundaries[end]["kind"]!=kind
                boundary_observe(integrator,kind)
                if two_pass && count(b->b["kind"]=="exit",boundaries)==2
                    SimulationEngine.terminate!(integrator)
                end
            end
        end
        env=CH._edg_targeting_prediction_environment(p,R,V,Float64(t))
        if !isempty(st.heat_load_exit_j_cm2[1])
            key=Tuple(st.heat_load_exit_j_cm2[1])
            if !(key in seen_exits)
                push!(seen_exits,key)
                push!(passage_records,Dict("observed_at_s"=>t,"entry_panel_heat"=>copy(st.heat_load_entry_j_cm2[1]),"exit_panel_heat"=>copy(st.heat_load_exit_j_cm2[1]),"passage_heat"=>CH._edg_pass_heat_load_for_links(sc,(2,3),st,1)))
            end
        end
        if env.altitude_m>175000 && t-last_coast[]<30.0;return 0.0;end
        if env.altitude_m>175000;last_coast[]=t;end
        ang=c.links[2].α
        qdot=SM.getHeatRate(args.environment_model.thermal_model,env.molecular_speed_ratio,env.temperature,env.rho,env.speed,ang)
        energy=dot(V,V)/2-planet.μ/norm(R)
        ref=CH._energy_depletion_struct_drag_area(c,env.temperature,env.molecular_speed_ratio,(2,3),pi/2,config)
        dr=env.dynamic_pressure*CH._energy_depletion_struct_drag_area(c,env.temperature,env.molecular_speed_ratio,(2,3),ang,config)/ref
        push!(rows,Float64[t,(P*R)...,(P*V)...,norm(R)-planet.Rp_e,env.altitude_m,env.rho,env.temperature,env.speed,env.molecular_speed_ratio,ang,qdot,sc.heat_loads...,energy,dr,st.heat_load_switches_s[1]...,Float64(st.heat_load_switch_solved[1]),Float64(st.heat_load_drag_passage_active[1]),(st.selected_mode[1]==:targeting ? 2.0 : st.selected_mode[1]==:max_energy_depletion ? 1.0 : 0.0),st.targeting_switch_s[1],st.target_energy_jkg[1],st.bracket_min_energy_jkg[1],st.bracket_max_energy_jkg[1],Float64(st.energy_bracketing_count[1]),Float64(st.heat_load_security_active[1])])
        return 0.0
    end
    function boundary_observe(integrator,kind)
        u=integrator.u.sc[1];R=SVector{3,Float64}(u.pos);V=SVector{3,Float64}(u.vel)
        push!(boundaries,Dict("kind"=>kind,"time_s"=>Float64(integrator.t),"position_pci_m"=>collect(P*R),"velocity_pci_m_s"=>collect(P*V),"heat_loads_j_cm2"=>collect(u.heat_loads),"energy_j_kg"=>dot(V,V)/2-planet.μ/norm(R),"spherical_altitude_m"=>norm(R)-planet.Rp_e))
        println("BOUNDARY ",label," ",kind," ",integrator.t);flush(stdout)
        save_result(label*"_partial",Dict("spherical_boundaries"=>boundaries,"apoapses"=>apoapses))
    end
    function exit_observe(integrator)
        boundary_observe(integrator,"exit")
        if two_pass && count(b->b["kind"]=="exit",boundaries)==2
            observe(integrator.u,integrator.t,integrator)
            SimulationEngine.terminate!(integrator)
        end
    end
    cb=SimulationEngine.ContinuousCallback((u,t,int)->norm(u.sc[1].pos)-planet.Rp_e-160000,exit_observe,i->boundary_observe(i,"entry");save_positions=(true,true))
    function apo_observe(integrator)
        sc=integrator.u.sc[1];R=SVector{3,Float64}(sc.pos);V=SVector{3,Float64}(sc.vel)
        push!(apoapses,Dict("time_s"=>Float64(integrator.t),"radius_m"=>norm(R),"energy_j_kg"=>dot(V,V)/2-planet.μ/norm(R),"position_pci_m"=>collect(P*R),"velocity_pci_m_s"=>collect(P*V)))
        if !two_pass && any(b->b["kind"]=="exit",boundaries);SimulationEngine.terminate!(integrator);end
    end
    apo_cb=SimulationEngine.ContinuousCallback((u,t,int)->dot(u.sc[1].pos,u.sc[1].vel),nothing,apo_observe;save_positions=(true,true))
    accepted_cb=SimulationEngine.DiscreteCallback((u,t,i)->true,i->observe(i.u,i.t,i);initialize=(cb,u,t,i)->begin
        if !two_pass && abs(norm(u.sc[1].pos)-planet.Rp_e-160000)<1e-4
            i.opts.dtmax=dtmax
        end
        observe(u,t,i)
      end,save_positions=(false,false))
    started=time();result=Dict{String,Any}("source_parent"=>ENV["EDG_SOURCE_HEAD"],"runtime_source_modified"=>true,"candidate"=>"Extracted working source from parent "*ENV["EDG_SOURCE_HEAD"]*" identified by "*ENV["EDG_SOURCE_TREE"],"atmosphere"=>"native nominal Mars-GRAM","control_hz"=>3,"guidance_hz"=>3,"planet_mu"=>planet.μ,"planet_radius"=>planet.Rp_e,"rho_ref"=>planet.ρ_ref,"h_ref"=>planet.h_ref,"scale_height"=>planet.H,"temperature_source"=>"native nominal Mars-GRAM","initial_position_pci_m"=>collect(r_old),"initial_velocity_pci_m_s"=>collect(v_old),"initial_position_j2000_m"=>collect(r),"initial_velocity_j2000_m_s"=>collect(v),"frame_rotation_rows"=>[collect(P[i,:]) for i in 1:3],"initial_energy_j_kg"=>dot(v,v)/2-planet.μ/norm(r),"dtmax"=>dtmax)
    try
      sol=SimulationEngine.run_simulation(args;return_solution=true,save_fields=[SM.SaveField(:comparison,(u,t,i)->0.0)],extra_callbacks=(apo_cb,accepted_cb,))
      result["retcode"]=string(sol.retcode);result["final_time"]=isempty(sol.t) ? last_observed[] : last(sol.t);result["status"]="completed"
    catch err
      result["status"]="failed";result["error"]=sprint(showerror,err);showerror(stdout,err,catch_backtrace());println();flush(stdout)
    end
    result["native_density_calls"]=native_calls[]-native_start
    result["native_requests"]=native_requests[]-requests_start
    result["exact_cache_hits"]=native_cache_hits[]-hits_start
    result["independently_recomputed_cache_hits"]=native_checked_hits[]-checked_start
    result["target_selection"]=selection
    result["planning_records"]=planning_records
    result["elapsed_s"]=time()-started;result["spherical_boundaries"]=boundaries;result["apoapses"]=apoapses;result["exact_geodetic_heat_records"]=passage_records;result["targeting"]=targeting;result["two_pass"]=two_pass;result["target_radius_m"]=target_radius;result["initialization"]=two_pass ? "preceding apoapsis" : "incoming spherical160km"
    open(joinpath(ROOT,label*".csv"),"w") do io
      println(io,"time,x,y,z,vx,vy,vz,spherical_altitude,geodetic_altitude,rho,T,relative_speed,S,alpha,heat_rate,bus_heat,left_heat,right_heat,energy,structural_proxy,switch1,switch2,switch_solved,in_pass,mode,target_switch,target_energy,bracket_min,bracket_max,bracket_count,security_active")
      for row in rows;println(io,join(row,","));end
    end
    save_result(label,result);println("COMPARISON_RESULT ",result);flush(stdout)
    @assert result["status"]=="completed"
    return result
end
