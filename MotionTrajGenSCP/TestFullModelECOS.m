% Test full model

theta_init = [1, 0.1, -0.4, 0.6]';   % corresponds to (x,y,z) = (1.2475, -0.3431, -0.4801);
theta_final = [-1, 0.3, -0.5, 0.7]'; % corresponds to (x,y,z) = (0.5927, 0.0514, 2.5731);

%%%%%%%%%%%%%% PROBLEM PARAMETERS %%%%%%%%%%%%%%%%%
n = 4;           % # joint variables
T = 15;          % # time steps
ls = 3*T;        % # slack variables for position constraints (x,y,z) = 3 * T
lt = n*T;        % # theta variables total = #joints x #timesteps
lx = ls + 2*lt;  % # of variables for full problem

gamma = 1.1; % regularization on thetas
delta = 1.5; % penalty factor on position infeasibilities
SCP_itrs = 12;

t_lim_max = [2.0857, 0.3142, 2.0857, 1.5446]';    % joint ranges max lim
t_lim_min = [-2.0857, -1.3265, -2.0857, 0.0349]'; % joint ranges min lim

theta_radius = 0.075; % initial radius of deviation
theta_linspace = getThetaLinspace(theta_init, theta_final, T); % size n x T
theta_min = vec(theta_linspace - theta_radius);
theta_max = vec(theta_linspace + theta_radius);

%%% VARIABLE NOTATION: %%%
%
% x = [s, theta, v]
% where theta = [t1(t=1), t2(t=1), t3(t=1), t4(t=1), t1(t=2), t2(t=2), t3(t=2), t4(t=2), t1(t=3), ..., t1(t=T), t2(t=T), t3(t=T), t4(t=T)]
%
% v follows a the same format. 
%
% s is similar, except it will be [..., x(t=ti), y(t=ti), z(t=ti), ...] as
% they are the position constraint slack variables. 
%
% Useful macros: sub-select [s, t, v] portions of x
get_s_from_x = @(x, ls, lt) (x(1:ls));
get_t_from_x = @(x, ls, lt) (x(ls+1:ls+lt));

% We have enough to construct the object and inequality constraints; test:
Zts = zeros(lt, ls);
Zst = zeros(ls, lt); 
Ztt = zeros(lt, lt);
Zss = zeros(ls, ls);
It = eye(lt); 
Is = eye(ls);
I_t = [zeros(n,n), zeros(n, lt-n); zeros(lt-n, n), eye(lt - n)];

Gineq = ...
[Zts, It, -It;  % + theta_linspace in h
 Zts, -It, -It; % - theta_linspace in h
 -Is, Zst, Zst;
 Zts, It, Ztt;
 Zts, -It, Ztt];

zt = zeros(lt, 1); zs = zeros(ls, 1);
%hineq = [zt; zt; zs; theta_max; -theta_min];
hineq = [vec(theta_linspace); -vec(theta_linspace); zs; theta_max; -theta_min];

is = ones(ls, 1); it = ones(lt, 1);
c_objective = [delta*is; zt; gamma*it];

% Equalities: 
it1 = [ones(n,1); zeros(lt - n, 1)];
itT = [zeros(lt - n, 1); ones(n,1)];

Aeq = zeros(2*n, lx);
for i=1:n
    Aeq(i, ls+1 + (i-1)) = 1; % for t1(t=1), ..., tn(t=1)
end
for i=1:n % draw it out, do trial and error with indexing...
    Aeq(i+n, ls+1 + lt - n + i - 1) = 1; % for t1(t=T), ..., tn(t=T)
end

 L2normMat = ...
     [Zss, Zst, Zst;
      Zts, Ztt, Ztt;
      Zts, It, Ztt];

beq = [theta_init; theta_final];
 
% cvx_begin
%     variable x(lx)
%     minimize (c_objective'*x)
%     subject to 
%         Gineq*x <= hineq
%         Aeq*x == beq;
%         %x(1:ls) == 0 % use this to test maximize
% cvx_end
% 
% t_test = get_t_from_x(x,ls,lt);
% figure; plot(t_test - vec(theta_linspace)); % should all be -theta_radius!! since we minimized.
% with equalities, will see first n and last n residuals be zero from the
% theta_linspace vec. 

% INEQUALITY CONSTRAINTS: POSITION BOUNDS
%
% Start by generating obstacle avoidance path:
y_init = NaoRH_fwd_py(theta_init); z_init = NaoRH_fwd_pz(theta_init);
% Below must be consistent with 'setupobstacle.m':
% e.g. obs{3}.R = 0.9; obs{3}.c = [1.3;-0.6;1;];
p_xyz = [1.1;-0.6;1;]; radius = 0.8;
% Generate the bounds for y and z: 
[Uz, Lz, Uy, Ly] = ObstacleAvoidancePath(y_init, z_init, theta_linspace, p_xyz, radius);

% Generate the approximation matrices based on the current theta: (starts with theta_linspace)
xyz_linspace = GetXYZlinspace(NaoRH, theta_linspace);
plot_xyz_path(xyz_linspace, 0);

% Create selector theta(t) selector matrices to use with the 2nd order function approximations
% In this loop, we will also create the 2nd order approximation matrices:
t_theta_selectors = cell(T,1);
t_s_y_selectors = cell(T,1);
t_s_z_selectors = cell(T,1);
% Below: to hold the SOC constraints (from quadratics)
% Why 4: because we are doing (y,z) less-than and greater-than constraints
numTimeSOCConstraints = 4;
isQuadOn = 0; % set to 1 if using quadratic regularization %TODO - get this working
Bk0_mat = cell(numTimeSOCConstraints*(T) + isQuadOn,1); % each of size (mi_vec(i)-1) x n
dk0_vec = cell(numTimeSOCConstraints*(T) + isQuadOn,1); % (mi - 1) x 1
Bk1_vec = cell(numTimeSOCConstraints*(T) + isQuadOn,1); % each is 1 x n 
dk1_scalar = cell(numTimeSOCConstraints*(T) + isQuadOn,1); % each is 1 x 1
%+1 in number of cones because of the L2 regularization

for i=1:T
    
   % Part I: t_selector matrices:
   t_theta_selectors{i} = zeros(n,lx); 
   t_s_y_selectors{i} = zeros(lx,1); t_s_z_selectors{i} = zeros(lx,1);
   for j=1:n
       t_theta_selectors{i}(j, ls+1 + (i-1)*n + (j-1)) = 1; % for t1(t=i), ..., tn(t=i) %% was j-1 before loop change to 1:T-2
   end
   t_s_y_selectors{i}((i-1)*3 + 2) = 1; t_s_z_selectors{i}((i-1)*3 + 3) = 1;
   % The above are penalties on position infeasibilities
   
   % Part II: 2nd-order approximation params (this part gets repeated after every optimization solve)
   phi = theta_linspace(:,i);
   [Hcvx_px, Hccv_px, g_px, Hcvx_py, Hccv_py, g_py, Hcvx_pz, Hccv_pz, g_pz ] = NaoRH_fwd_approx_params(phi);
   
   % Part III: create the numTimeSOCConstraints*(T-2) set of SOC constraints (repeated)
   % 
   % First we form (P,q,r) as in (1/2)*x'*P*x + q'*x + r <= 0
   % Then we convert to SOC form.
   % 'Pyg' means 'P for y-greater-than' constraint, 
   % 'qzl' means 'q for z-less-than' constraint, etc.
   Pyg = t_theta_selectors{i}'*Hcvx_py*t_theta_selectors{i};
   qyg = -t_s_y_selectors{i} + t_theta_selectors{i}'*(g_py - Hcvx_py*phi);
   ryg = NaoRH_fwd_py(phi) - g_py'*phi + phi'*Hcvx_py*phi - Uy(i);
   
   Pyl = -t_theta_selectors{i}'*Hccv_py*t_theta_selectors{i};
   qyl = -t_s_y_selectors{i} - t_theta_selectors{i}'*(g_py - Hccv_py*phi);
   ryl = -NaoRH_fwd_py(phi) + g_py'*phi - phi'*Hccv_py*phi + Ly(i);
   
   Pzg = t_theta_selectors{i}'*Hcvx_pz*t_theta_selectors{i};
   qzg = -t_s_z_selectors{i} + t_theta_selectors{i}'*(g_pz - Hcvx_pz*phi);
   rzg = NaoRH_fwd_pz(phi) - g_pz'*phi + phi'*Hcvx_pz*phi - Uz(i);
   
   Pzl = -t_theta_selectors{i}'*Hccv_pz*t_theta_selectors{i};
   qzl = -t_s_z_selectors{i} - t_theta_selectors{i}'*(g_pz - Hccv_pz*phi);
   rzl = -NaoRH_fwd_pz(phi) + g_pz'*phi - phi'*Hccv_pz*phi + Lz(i);
   
   idx = (i-1)*numTimeSOCConstraints;
   [Bk0_mat{idx+1}, dk0_vec{idx+1}, Bk1_vec{idx+1}, dk1_scalar{idx+1}] = QuadraticToSOC(Pyg, qyg, ryg);
   [Bk0_mat{idx+2}, dk0_vec{idx+2}, Bk1_vec{idx+2}, dk1_scalar{idx+2}] = QuadraticToSOC(Pyl, qyl, ryl);
   [Bk0_mat{idx+3}, dk0_vec{idx+3}, Bk1_vec{idx+3}, dk1_scalar{idx+3}] = QuadraticToSOC(Pzg, qzg, rzg);
   [Bk0_mat{idx+4}, dk0_vec{idx+4}, Bk1_vec{idx+4}, dk1_scalar{idx+4}] = QuadraticToSOC(Pzl, qzl, rzl);
   
end
% TODO - get 2 norm working
%[Bk0_mat{idx+5}, dk0_vec{idx+5}, Bk1_vec{idx+5}, dk1_scalar{idx+5}] = QuadraticToSOC(2*L2normMat, [zeros(ls+lt,1);gamma*ones(lt,1)], 0);
% Add the L2 norm cone constraint (which we shouldn't need to re-add)

%%%%%%%%%%%%%%%%%%%%%%% THE MAIN EVENT %%%%%%%%%%%%%%%%%%%%%%%%%%%

p_star_series = zeros(SCP_itrs, 1);
mi_vec = (lx+2)*ones(numTimeSOCConstraints*(T)+ isQuadOn,1); %+1 for how we transform quadratic to SOC; +1 for SOC convention
%+1 in number of cones because of the L2 regularization

[G, h] = PrepareEcos(Bk0_mat, dk0_vec, Bk1_vec, dk1_scalar, mi_vec, size(mi_vec,1), lx);
G = [Gineq; G];
h = [hineq; h];

dims.l = 4*lt + ls;
dims.q = mi_vec;

[x_star_ecos,y_star_ecos,info,s,z] = ecos(c_objective,sparse(G),h,dims,sparse(Aeq),beq);
p_star_ecos = info.pcost; p_star_series(1) = ComputeTrueObjective(delta, c_objective, x_star_ecos, Uy, Uz, Ly, Lz, ls, lt, lx, n, T); %p_star_ecos;
p_star_prev = p_star_ecos;

theta_new = get_t_from_x(x_star_ecos, ls, lt);
theta_new_matrix = reshape(theta_new,[n,T]);
% Plot how our trajectory is moving: 
xyz_linspace = GetXYZlinspace(NaoRH, theta_new_matrix);
plot_xyz_path(xyz_linspace, 0);

%%%%%%%%%%%%%%%%%%%%% Repeat until... %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initial: try a set number of iterations
for itrs=2:SCP_itrs
    
    % Recreate the problem using the solution from the previous iteration.
    % Only recreate the parts we need to not waste computation.
    % Part I: new theta limits:
    theta_min = vec(ClampX(theta_new_matrix - theta_radius, t_lim_min, t_lim_max));
    theta_max = vec(ClampX(theta_new_matrix + theta_radius, t_lim_min, t_lim_max));
    %hineq = [zt; zt; zs; theta_max; -theta_min];
    hineq = [vec(theta_linspace); -vec(theta_linspace); zs; theta_max; -theta_min];

    for i=1:T
       % Part II: 2nd-order approximation params (this part gets repeated after every optimization solve)
       phi = theta_new_matrix(:,i); % approximate about our previous solution (!!)
       [Hcvx_px, Hccv_px, g_px, Hcvx_py, Hccv_py, g_py, Hcvx_pz, Hccv_pz, g_pz ] = NaoRH_fwd_approx_params(phi);
       % Part III: create the 4*(T) set of SOC constraints (repeated)
       % 
       % First we form (P,q,r) as in (1/2)*x'*P*x + q'*x + r <= 0
       % Then we convert to SOC form.
       % 'Pyg' means 'P for y-greater-than' constraint, 
       % 'qzl' means 'q for z-less-than' constraint, etc.
       Pyg = t_theta_selectors{i}'*Hcvx_py*t_theta_selectors{i};
       qyg = -t_s_y_selectors{i} + t_theta_selectors{i}'*(g_py - Hcvx_py*phi);
       ryg = NaoRH_fwd_py(phi) - g_py'*phi + phi'*Hcvx_py*phi - Uy(i);
       Pyl = -t_theta_selectors{i}'*Hccv_py*t_theta_selectors{i};
       qyl = -t_s_y_selectors{i} - t_theta_selectors{i}'*(g_py - Hccv_py*phi);
       ryl = -NaoRH_fwd_py(phi) + g_py'*phi - phi'*Hccv_py*phi + Ly(i);
       Pzg = t_theta_selectors{i}'*Hcvx_pz*t_theta_selectors{i};
       qzg = -t_s_z_selectors{i} + t_theta_selectors{i}'*(g_pz - Hcvx_pz*phi);
       rzg = NaoRH_fwd_pz(phi) - g_pz'*phi + phi'*Hcvx_pz*phi - Uz(i);
       Pzl = -t_theta_selectors{i}'*Hccv_pz*t_theta_selectors{i};
       qzl = -t_s_z_selectors{i} - t_theta_selectors{i}'*(g_pz - Hccv_pz*phi);
       rzl = -NaoRH_fwd_pz(phi) + g_pz'*phi - phi'*Hccv_pz*phi + Lz(i);
       idx = (i-1)*numTimeSOCConstraints;
       [Bk0_mat{idx+1}, dk0_vec{idx+1}, Bk1_vec{idx+1}, dk1_scalar{idx+1}] = QuadraticToSOC(Pyg, qyg, ryg);
       [Bk0_mat{idx+2}, dk0_vec{idx+2}, Bk1_vec{idx+2}, dk1_scalar{idx+2}] = QuadraticToSOC(Pyl, qyl, ryl);
       [Bk0_mat{idx+3}, dk0_vec{idx+3}, Bk1_vec{idx+3}, dk1_scalar{idx+3}] = QuadraticToSOC(Pzg, qzg, rzg);
       [Bk0_mat{idx+4}, dk0_vec{idx+4}, Bk1_vec{idx+4}, dk1_scalar{idx+4}] = QuadraticToSOC(Pzl, qzl, rzl);
    end
    
    % Part IV: ECOS
    
    c_objective = [delta*is; zt; gamma*it];
    [G, h] = PrepareEcos(Bk0_mat, dk0_vec, Bk1_vec, dk1_scalar, mi_vec, size(mi_vec,1), lx);
    G = [Gineq; G];
    h = [hineq; h];
    [x_star_ecos,y_star_ecos,info,s,z] = ecos(c_objective,sparse(G),h,dims,sparse(Aeq),beq);
    p_star_ecos = info.pcost; p_star_series(itrs) = ComputeTrueObjective(delta, c_objective, x_star_ecos, Uy, Uz, Ly, Lz, ls, lt, lx, n, T); %p_star_ecos;
    p_star_prev = p_star_ecos;

    theta_new = get_t_from_x(x_star_ecos, ls, lt);
    theta_new_matrix = reshape(theta_new,[n,T]);
    % Plot how our trajectory is moving: 
    xyz_linspace = GetXYZlinspace(NaoRH, theta_new_matrix);
    plot_xyz_path(xyz_linspace, 0);
    
end
%plot_xyz_path(xyz_linspace, 1);
figure; plot(p_star_series);
