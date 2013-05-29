function fn_save = create_loss_parameters(eta1, eta2, lambda, dir_name)


% mean and variance for the poison noise
% lambda
%
% var = eta1*mu+eta2*mu^2

fn_save = sprintf('%s/loss_param_lambda-%i_eta1-%.2f_eta2-%.2f.mat', dir_name, lambda, eta1, eta2);

if fexist(fn_save)
	return
end

do_plot = 1;

if do_plot
	figure
end

% this is the observed coverage:
xpos=[1 2 3 5 10 15 20 35 50 100 200 500 1000 5000 10000 30000] ;

s=0; 
for obs=xpos ;
	s=s+1 ;
	step=obs/500+0.002 ;

	% mean of the negative binomial
	%mus=(0.001):step:(obs*3+1);
	%mus=(obs/10+0.001):step:(obs*3+5);
	std_=sqrt(eta1*obs + eta2*obs^2);
	mus=max(1, obs-2*std_):step:(obs+5*std_);

	
	Y4 = zeros(1, length(mus));
	for k=1:length(mus),
		mu = mus(k);
		var = eta1*mu + eta2*mu^2;
		[r p] = compute_rp_neg_binom(mu, var); 
		% A ~ Pois(lambda)
		% B ~ NB(r,p)
		% obs = A+B 
		%
		for i = 0:min(obs, 100)
			pois = i*log(lambda) - lambda - factln(i); 
			nb = factln(obs-i+r-1) - factln(obs-i) - factln(r-1) + r*log(1-p) + (obs-i)*log(p); 
			Y4(k) = Y4(k) + exp(pois+nb); 
		end
	end ;
	Y4(Y4<1e-200) = 1e-200;
	Y = -log(Y4);

	%clf
	%plot(mus, Y), hold on, plot(mus, -log(Y4), 'r'); 
	%keyboard
	%continue


	X=[(mus-obs).^2; abs(mus-obs)] ;
	idx1=find(mus<=obs) ;
	idx2=find(mus>=obs) ;
	%Y=-log(P') ;
	Y = Y';
	if ~isempty(idx1)
		offset=Y(idx1(end)) ;
	else
		offset=Y(idx2(1));
	end

	w1=X(:,idx1)'\(Y(idx1)-offset) ;
	w2=X(:,idx2)'\(Y(idx2)-offset) ;
	
	% fit the function locally: fit is more exact close to the 
	% observed value than far away from it
	WWA=exp(-(mus-obs).^2./median(((mus-obs)).^2)) ;
	opts =  optimset('MaxFunEvals', 10000, 'MaxIter', 10000);
	
	if 1,
	    if w1(1)<0, w1(1)=0 ; end ;
		w1 = [0;0];
	    global XX YY WW
	    XX=X(:,idx1)' ;
	    YY=Y(idx1)-offset;
	    WW=WWA(idx1) ;
		if 0%(exist('fmincon')==2)
	   		w1 = fmincon(@(w) mean(WW'.*((XX*w-YY).^2)),w1,[],[], [], [], [1e-10 10], [10 1e-10]) 
		else
			w1 = my_min(XX, YY, WW, [1e-10 10], [10 1e-10])
		end
	    E_left=mean(WW'.*((XX*w1-YY).^2))
	
		if 0% all(w1==0)
			figure, hold on
			plot(mus(idx1), WW), plot(mus(idx1), YY), plot(mus(idx1), XX*[1e-7;1e-1], 'g')
			keyboard
		end
	    
	    if w2(1)<0, w2(1)=0 ; end ;
	    global XX YY
	    XX=X(:,idx2)' ;
	    YY=Y(idx2)-offset ;
	    WW=WWA(idx2);
		if 0%(exist('fmincon')==2)
	    	w2 = fmincon(@(w) mean(WW'.*((XX*w-YY).^2)),w2,[],[], [], [], [1e-10 0.5], [10 1e-10])
		else
			w2 = my_min(XX, YY, WW, [1e-10 0.5], [10 1e-10])
		end
	    E_right=mean(WW'.*((XX*w2-YY).^2))
	end ;
	
	left_q(s)=w1(1);
	left_l(s)=w1(2);
	right_q(s)=w2(1);
	right_l(s)=w2(2);

	if isnan(w1(1)) || isnan(w2(1))
		keyboard
	end
	
	if do_plot
		subplot(4,5,s) ;
		%figure
		semilogy(mus, Y, mus(idx1), (X(:,idx1)'*w1)'+offset, mus(idx2), (X(:,idx2)'*w2)'+offset)
		%title(sprintf('obs=%1.2f, E_{left}=%1.4f, E_{right}=%1.4f', obs, E_left, E_right)) ;
		%plot(mus,-log(P), mus, offset+(log(mus)-log(obs)).^2) ;
	end

end ;
save(fn_save, 'xpos', 'left_l', 'left_q', 'right_l', 'right_q')

return

function w_best = my_min(XX, YY, WW, box1, box2)

	eps = 1e-15;
	w = [box1(1); box2(1)];
	best = mean(WW'.*((XX*w-YY).^2));
	best_orig = best;
	w_best = w;
	iter = 0;
	% weighted least squares
	while abs(box1(2)-box1(1))>eps || abs(box2(2)-box2(1))>eps 
		steps1 = box1(1):(box1(2)-box1(1))/10:box1(2);
		steps2 =  box2(1):(box2(2)-box2(1))/10:box2(2);

		best = best_orig;
		for val1 = steps1
			for val2 = steps2
				w = [val1; val2];
				val = mean(WW'.*((XX*w-YY).^2));
				if val<best
					best = val;
					w_best = w;
				end
			end
		end	
		if abs(box1(2)-box1(1))>eps
			idx = find(w_best(1)==steps1, 1, 'first');
			if idx>1 && idx<length(steps1)
				box1 = [steps1(idx-1), steps1(idx+1)];
			elseif idx>1
				box1 = [steps1(end-1), steps1(end)];
			else
				box1 = [steps1(1), steps1(2)];
			end
		end
		box2_tmp = box2;
		if abs(box2(2)-box2(1))>eps
			idx = find(w_best(2)==steps2, 1, 'first');
			if idx>1 && idx<length(steps2)
				box2 = [steps2(idx-1), steps2(idx+1)];
			elseif idx>1
				box2 = [steps2(end-1), steps2(end)];
			else
				box2 = [steps2(1), steps2(2)];
			end
		end
		iter = iter+1;
		if iter>200 % may happen for numerical reasons if eps too small
			break
		end
	end
	iter
return

function [r, p] = compute_rp_neg_binom(mu,var)

p = 1-(mu/var);
%p = -(mu-2*var)/(2*var) - sqrt(((mu-2*var)/(2*var))^2 +mu/var -1);
r = mu*(1-p)/p;
return