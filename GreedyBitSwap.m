function [p_star, x_hat] = GreedyBitSwap(x_hat_initial, p_star_initial, W, n)

    x_hat = x_hat_initial;
    p_star = p_star_initial;
    p_star_prev = p_star + 1; % to start the progress loop

    while (p_star < p_star_prev) 
        %disp('bitswap');
        % while bit swapping keeps making progress
        p_star_prev = p_star; % update previous

        % cycle through all bits:
        for i=1:n
            test_x = x_hat;
            if (test_x(i) == -1)
                test_x(i) = 1;
            elseif (test_x(i) == 1)
                test_x(i) = -1;
            else
                disp('error: x_hat not made of +/- 1!');
            end

            % Test it: 
            test_p_star = test_x'*W*test_x;
            if (test_p_star < p_star)
                x_hat = test_x;
                p_star = test_p_star;
            end
        end
    end
end