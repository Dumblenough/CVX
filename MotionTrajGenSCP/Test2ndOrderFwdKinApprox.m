% Test 2nd Order Approximations of fwd_kin functions

Xmax = [2.0857, 0.3142, 2.0857, 1.5446]';
Xmin = [-2.0857, -1.3265, -2.0857, 0.0349]';

% MAIN LOOP: Generate a random test point, and test the error for small
% perturbations around it. 

% 0. Choose a point
T = 200;
thetas = GenerateRandomX(Xmin, Xmax, T);

% 1. Get approximation parameters
%[Hcvx_px, Hccv_px, g_px, Hcvx_py, Hccv_py, g_py, Hcvx_pz, Hccv_pz, g_pz ] = NaoRH_fwd_approx_params(theta);

% 2. Form functions

% Approximates p[x,y,z](t) about t=theta
p_approx_2 = @(t, theta, f, g, H) (f + g'*(t - theta) + 0.5*(t - theta)'*H*(t - theta));

p_approx_3 = @(t, theta, f, g, Hcvx, Hccv) (0.5*t'*(Hccv)*t + (g-(Hccv)*theta)'*t + (f-g'*theta+0.5*theta'*(Hccv)*theta));



radius = 0.2; % so our deviation is (t-r) to (t+r)
Jlim = 200; % how many points within the above deviation to test
errors_x = zeros(Jlim*T,1); errors_y = zeros(Jlim*T,1); errors_z = zeros(Jlim*T,1);
for i=1:T
   
    % APPROXIMATION POINT
    theta = thetas(:,i);
    [Hcvx_px, Hccv_px, g_px, Hcvx_py, Hccv_py, g_py, Hcvx_pz, Hccv_pz, g_pz ] = NaoRH_fwd_approx_params(theta);
    
    
    % TESTING ABOUT THE APPROXIMATION POINT
    for j=1:Jlim
        
        theta_test = ClampX(theta+radius*2*(rand(size(theta))-0.5), Xmin, Xmax);
        
        % REFERENCE - actual forward kin
        Tfkine = NaoRH.fkine(theta_test);
        x_ref = NaoRH_fwd_px(theta); % Tfkine(1,4); %
        y_ref = NaoRH_fwd_py(theta); % Tfkine(2,4); %
        z_ref = NaoRH_fwd_pz(theta); % Tfkine(3,4); %
        
        %x_test = p_approx_2(theta_test, theta, NaoRH_fwd_px(theta), g_px, Hcvx_px);
        %y_test = p_approx_2(theta_test, theta, NaoRH_fwd_py(theta), g_py, Hcvx_py);
        %z_test = p_approx_2(theta_test, theta, NaoRH_fwd_pz(theta), g_pz, Hcvx_pz);
        
        x_test = p_approx_3(theta_test, theta, NaoRH_fwd_px(theta), g_px, Hcvx_px, Hccv_px);
        y_test = p_approx_3(theta_test, theta, NaoRH_fwd_py(theta), g_py, Hcvx_py, Hccv_px);
        z_test = p_approx_3(theta_test, theta, NaoRH_fwd_pz(theta), g_pz, Hcvx_pz, Hccv_px);
        
        errors_x((i-1)*Jlim + j) = abs(x_ref - x_test);
        errors_y((i-1)*Jlim + j) = abs(y_ref - y_test);
        errors_z((i-1)*Jlim + j) = abs(z_ref - z_test);
    end
end
errors = (errors_x + errors_y + errors_z)/3;

figure; hist(errors);

mean(errors)