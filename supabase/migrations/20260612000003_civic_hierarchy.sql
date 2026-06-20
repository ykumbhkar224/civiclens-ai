-- Migration: civic hierarchy lookup
-- Adds constituency mapping, politician data, and pincode lookup

-- ── Extend representatives table ─────────────────────────────────────────────
ALTER TABLE public.representatives
  ADD COLUMN IF NOT EXISTS type text DEFAULT 'other'
    CHECK (type IN ('mla', 'mp', 'councillor', 'other')),
  ADD COLUMN IF NOT EXISTS pincode text,
  ADD COLUMN IF NOT EXISTS state text;

-- ── Add pincode to reports ───────────────────────────────────────────────────
ALTER TABLE public.reports ADD COLUMN IF NOT EXISTS pincode text;

-- ── Pincode → constituency mapping ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pincode_constituencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pincode text NOT NULL UNIQUE,
  state text NOT NULL,
  district text NOT NULL,
  city text NOT NULL,
  assembly_constituency text,
  parliament_constituency text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pc_pincode ON public.pincode_constituencies(pincode);
CREATE INDEX IF NOT EXISTS idx_pc_city    ON public.pincode_constituencies(city);

ALTER TABLE public.pincode_constituencies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public read pincode_constituencies"
  ON public.pincode_constituencies FOR SELECT USING (true);

-- ── Seed: pincode → constituency ─────────────────────────────────────────────
INSERT INTO public.pincode_constituencies
  (pincode, state, district, city, assembly_constituency, parliament_constituency)
VALUES
-- Mumbai (South)
('400001','Maharashtra','Mumbai City','Mumbai','Colaba','Mumbai South'),
('400002','Maharashtra','Mumbai City','Mumbai','Byculla','Mumbai South'),
('400004','Maharashtra','Mumbai City','Mumbai','Malabar Hill','Mumbai South'),
('400005','Maharashtra','Mumbai City','Mumbai','Worli','Mumbai South'),
('400006','Maharashtra','Mumbai City','Mumbai','Shivdi','Mumbai South'),
('400007','Maharashtra','Mumbai City','Mumbai','Dharavi','Mumbai North Central'),
('400010','Maharashtra','Mumbai City','Mumbai','Mahim','Mumbai North Central'),
('400011','Maharashtra','Mumbai City','Mumbai','Sion Koliwada','Mumbai North Central'),
('400020','Maharashtra','Mumbai City','Mumbai','Matunga','Mumbai North Central'),
('400021','Maharashtra','Mumbai City','Mumbai','Dadar','Mumbai North Central'),
-- Mumbai (North West)
('400024','Maharashtra','Mumbai Suburban','Mumbai','Vile Parle','Mumbai North West'),
('400050','Maharashtra','Mumbai Suburban','Mumbai','Santacruz','Mumbai North West'),
('400051','Maharashtra','Mumbai Suburban','Mumbai','Santacruz','Mumbai North West'),
('400052','Maharashtra','Mumbai Suburban','Mumbai','Vile Parle','Mumbai North West'),
('400053','Maharashtra','Mumbai Suburban','Mumbai','Andheri West','Mumbai North West'),
('400054','Maharashtra','Mumbai Suburban','Mumbai','Andheri West','Mumbai North West'),
('400056','Maharashtra','Mumbai Suburban','Mumbai','Juhu','Mumbai North West'),
('400059','Maharashtra','Mumbai Suburban','Mumbai','Goregaon','Mumbai North West'),
('400060','Maharashtra','Mumbai Suburban','Mumbai','Goregaon','Mumbai North West'),
('400068','Maharashtra','Mumbai Suburban','Mumbai','Goregaon','Mumbai North West'),
-- Mumbai (North)
('400047','Maharashtra','Mumbai Suburban','Mumbai','Malad East','Mumbai North'),
('400061','Maharashtra','Mumbai Suburban','Mumbai','Kandivali East','Mumbai North'),
('400063','Maharashtra','Mumbai Suburban','Mumbai','Borivali','Mumbai North'),
('400064','Maharashtra','Mumbai Suburban','Mumbai','Dahisar','Mumbai North'),
('400066','Maharashtra','Mumbai Suburban','Mumbai','Malad West','Mumbai North'),
('400092','Maharashtra','Mumbai Suburban','Mumbai','Kandivali East','Mumbai North'),
('400097','Maharashtra','Mumbai Suburban','Mumbai','Kandivali West','Mumbai North'),
-- Mumbai (North East)
('400057','Maharashtra','Mumbai Suburban','Mumbai','Andheri East','Mumbai North East'),
('400058','Maharashtra','Mumbai Suburban','Mumbai','Andheri East','Mumbai North East'),
('400069','Maharashtra','Mumbai Suburban','Mumbai','Ghatkopar West','Mumbai North East'),
('400070','Maharashtra','Mumbai Suburban','Mumbai','Kurla','Mumbai North East'),
('400072','Maharashtra','Mumbai Suburban','Mumbai','Powai','Mumbai North East'),
('400075','Maharashtra','Mumbai Suburban','Mumbai','Ghatkopar East','Mumbai North East'),
('400078','Maharashtra','Mumbai Suburban','Mumbai','Bhandup West','Mumbai North East'),
('400080','Maharashtra','Mumbai Suburban','Mumbai','Mulund','Mumbai North East'),
('400081','Maharashtra','Mumbai Suburban','Mumbai','Bhandup West','Mumbai North East'),
('400082','Maharashtra','Mumbai Suburban','Mumbai','Vikhroli','Mumbai North East'),
('400086','Maharashtra','Mumbai Suburban','Mumbai','Vikhroli','Mumbai North East'),
('400091','Maharashtra','Mumbai Suburban','Mumbai','Andheri East','Mumbai North East'),
-- Thane / Navi Mumbai
('400601','Maharashtra','Thane','Thane','Thane','Thane'),
('400604','Maharashtra','Thane','Thane','Kopri-Pachpakhadi','Thane'),
('400703','Maharashtra','Thane','Navi Mumbai','Belapur','Thane'),
-- Pune
('411001','Maharashtra','Pune','Pune','Pune Cantonment','Pune'),
('411002','Maharashtra','Pune','Pune','Kasba Peth','Pune'),
('411004','Maharashtra','Pune','Pune','Shivajinagar','Pune'),
('411011','Maharashtra','Pune','Pune','Parvati','Pune'),
('411030','Maharashtra','Pune','Pune','Kothrud','Pune'),
('411015','Maharashtra','Pune','Pune','Hadapsar','Baramati'),
('411038','Maharashtra','Pune','Pune','Chinchwad','Maval'),
-- Delhi
('110001','Delhi','Central Delhi','Delhi','Chandni Chowk','Chandni Chowk'),
('110002','Delhi','Central Delhi','Delhi','Ballimaran','Chandni Chowk'),
('110005','Delhi','West Delhi','Delhi','Patel Nagar','West Delhi'),
('110006','Delhi','Central Delhi','Delhi','Sadar Bazar','Chandni Chowk'),
('110008','Delhi','West Delhi','Delhi','Rajouri Garden','West Delhi'),
('110010','Delhi','South Delhi','Delhi','Greater Kailash','South Delhi'),
('110013','Delhi','South Delhi','Delhi','Jangpura','New Delhi'),
('110016','Delhi','South Delhi','Delhi','Saket','South Delhi'),
('110017','Delhi','South Delhi','Delhi','Mehrauli','South Delhi'),
('110019','Delhi','South Delhi','Delhi','Kalkaji','South Delhi'),
('110021','Delhi','South Delhi','Delhi','Janakpuri','West Delhi'),
('110022','Delhi','South Delhi','Delhi','R K Puram','New Delhi'),
('110023','Delhi','South Delhi','Delhi','New Delhi','New Delhi'),
('110025','Delhi','South Delhi','Delhi','Malviya Nagar','South Delhi'),
('110026','Delhi','South West Delhi','Delhi','Dwarka','West Delhi'),
('110027','Delhi','North West Delhi','Delhi','Rohini','North West Delhi'),
('110034','Delhi','North West Delhi','Delhi','Pitampura','North West Delhi'),
('110049','Delhi','South Delhi','Delhi','Mehrauli','South Delhi'),
('110054','Delhi','North Delhi','Delhi','Civil Lines','North East Delhi'),
('110085','Delhi','North East Delhi','Delhi','Mustafabad','North East Delhi'),
-- Bengaluru
('560001','Karnataka','Bengaluru Urban','Bengaluru','Shivajinagar','Bengaluru Central'),
('560003','Karnataka','Bengaluru Urban','Bengaluru','Chickpet','Bengaluru Central'),
('560004','Karnataka','Bengaluru Urban','Bengaluru','Basavanagudi','Bengaluru South'),
('560010','Karnataka','Bengaluru Urban','Bengaluru','Hebbal','Bengaluru North'),
('560011','Karnataka','Bengaluru Urban','Bengaluru','Rajajinagar','Bengaluru North'),
('560013','Karnataka','Bengaluru Urban','Bengaluru','Malleswaram','Bengaluru North'),
('560017','Karnataka','Bengaluru Urban','Bengaluru','Yeshwanthapur','Bengaluru North'),
('560038','Karnataka','Bengaluru Urban','Bengaluru','BTM Layout','Bengaluru South'),
('560039','Karnataka','Bengaluru Urban','Bengaluru','Jayanagar','Bengaluru South'),
('560047','Karnataka','Bengaluru Urban','Bengaluru','Mahadevapura','Bengaluru East'),
('560048','Karnataka','Bengaluru Urban','Bengaluru','KR Puram','Bengaluru East'),
('560049','Karnataka','Bengaluru Urban','Bengaluru','Whitefield','Bengaluru East'),
('560068','Karnataka','Bengaluru Urban','Bengaluru','Mahadevapura','Bengaluru East'),
-- Chennai
('600001','Tamil Nadu','Chennai','Chennai','Harbour','Chennai South'),
('600002','Tamil Nadu','Chennai','Chennai','Chepauk-Thiruvallikeni','Chennai Central'),
('600004','Tamil Nadu','Chennai','Chennai','Thousand Lights','Chennai Central'),
('600005','Tamil Nadu','Chennai','Chennai','Chepauk-Thiruvallikeni','Chennai Central'),
('600006','Tamil Nadu','Chennai','Chennai','Mylapore','Chennai South'),
('600007','Tamil Nadu','Chennai','Chennai','Royapuram','Chennai North'),
('600010','Tamil Nadu','Chennai','Chennai','Anna Nagar','North Chennai'),
('600017','Tamil Nadu','Chennai','Chennai','T.Nagar','Chennai Central'),
('600018','Tamil Nadu','Chennai','Chennai','Saidapet','Chennai South'),
('600020','Tamil Nadu','Chennai','Chennai','Velachery','Chennai South'),
('600046','Tamil Nadu','Chennai','Chennai','Sholinganallur','Chennai South'),
('600083','Tamil Nadu','Chennai','Chennai','Sholinganallur','Chennai South')
ON CONFLICT (pincode) DO NOTHING;

-- ── Seed representatives: MLAs, MPs, Councillors ─────────────────────────────
-- NOTE: Sample data for demonstration. Verify with official ECI sources.
INSERT INTO public.representatives
  (name, type, party, constituency, state, city, pincode, contact_phone, contact_email, role)
VALUES
-- Mumbai MLAs (Maharashtra 2024 Vidhan Sabha)
('Rahul Narwekar',    'mla','BJP',              'Colaba',          'Maharashtra','Mumbai','400001',null,null,'MLA & Speaker, Maharashtra Vidhan Sabha'),
('Amin Patel',        'mla','INC',              'Mumbadevi',       'Maharashtra','Mumbai','400002',null,null,'MLA'),
('Mangal Prabhat Lodha','mla','BJP',            'Malabar Hill',    'Maharashtra','Mumbai','400004',null,null,'MLA & Cabinet Minister'),
('Milind Deora',      'mla','Shiv Sena',        'Worli',           'Maharashtra','Mumbai','400005',null,null,'MLA'),
('Varsha Gaikwad',    'mla','INC',              'Dharavi',         'Maharashtra','Mumbai','400007',null,null,'MLA'),
('Sada Sarvankar',    'mla','Shiv Sena',        'Mahim',           'Maharashtra','Mumbai','400010',null,null,'MLA'),
('Ameet Satam',       'mla','BJP',              'Andheri West',    'Maharashtra','Mumbai','400053',null,null,'MLA'),
('Murji Patel',       'mla','BJP',              'Andheri East',    'Maharashtra','Mumbai','400057',null,null,'MLA'),
('Bharati Lavekar',   'mla','BJP',              'Versova',         'Maharashtra','Mumbai','400061',null,null,'MLA'),
('Parag Alavani',     'mla','BJP',              'Borivali',        'Maharashtra','Mumbai','400063',null,null,'MLA'),
('Vinod Ghosalkar',   'mla','Shiv Sena',        'Dahisar',         'Maharashtra','Mumbai','400064',null,null,'MLA'),
('Ajay Alve',         'mla','Shiv Sena',        'Goregaon',        'Maharashtra','Mumbai','400068',null,null,'MLA'),
('Vijay Nahata',      'mla','BJP',              'Mulund',          'Maharashtra','Mumbai','400080',null,null,'MLA'),
('Kiran Sheelar',     'mla','BJP',              'Vile Parle',      'Maharashtra','Mumbai','400052',null,null,'MLA'),
-- Mumbai MPs (Lok Sabha 2024)
('Arvind Sawant',     'mp','Shiv Sena (UBT)',   'Mumbai South',         'Maharashtra','Mumbai','400001',null,'arvind.sawant@sansad.nic.in','Member of Parliament, Lok Sabha'),
('Anil Desai',        'mp','Shiv Sena (UBT)',   'Mumbai South Central', 'Maharashtra','Mumbai','400010',null,null,'Member of Parliament, Lok Sabha'),
('Varsha Gaikwad',    'mp','INC',               'Mumbai North Central', 'Maharashtra','Mumbai','400020',null,null,'Member of Parliament, Lok Sabha'),
('Ravindra Waikar',   'mp','Shiv Sena',         'Mumbai North West',    'Maharashtra','Mumbai','400053',null,null,'Member of Parliament, Lok Sabha'),
('Piyush Goyal',      'mp','BJP',               'Mumbai North',         'Maharashtra','Mumbai','400063',null,null,'Member of Parliament & Union Minister, Lok Sabha'),
('Mihir Kotecha',     'mp','BJP',               'Mumbai North East',    'Maharashtra','Mumbai','400069',null,null,'Member of Parliament, Lok Sabha'),
-- Pune MLAs & MPs
('Chandrakant Patil', 'mla','BJP',  'Kothrud',        'Maharashtra','Pune','411030',null,null,'MLA & Cabinet Minister'),
('Siddharth Shirole', 'mp', 'BJP',  'Pune',           'Maharashtra','Pune','411001',null,null,'Member of Parliament, Lok Sabha'),
('Sunetra Pawar',     'mp', 'NCP',  'Baramati',       'Maharashtra','Pune','411015',null,null,'Member of Parliament, Lok Sabha'),
-- Delhi MLAs & MPs
('Arvind Kejriwal',   'mla','AAP',  'New Delhi',      'Delhi','Delhi','110023',null,null,'MLA, New Delhi'),
('Saurabh Bharadwaj', 'mla','AAP',  'Greater Kailash','Delhi','Delhi','110048',null,null,'MLA'),
('Sanjeev Jha',       'mla','AAP',  'Burari',         'Delhi','Delhi','110084',null,null,'MLA'),
('Parvesh Verma',     'mp', 'BJP',  'New Delhi',      'Delhi','Delhi','110023',null,null,'Member of Parliament, Lok Sabha'),
('Ramesh Bidhuri',    'mp', 'BJP',  'South Delhi',    'Delhi','Delhi','110025',null,null,'Member of Parliament, Lok Sabha'),
('Manoj Tiwari',      'mp', 'BJP',  'North East Delhi','Delhi','Delhi','110085',null,null,'Member of Parliament, Lok Sabha'),
-- Bengaluru MLAs & MPs
('Dinesh Gundu Rao',  'mla','INC',  'Shivajinagar',   'Karnataka','Bengaluru','560001',null,null,'MLA & Minister for Health'),
('Ramalinga Reddy',   'mla','INC',  'BTM Layout',     'Karnataka','Bengaluru','560038',null,null,'MLA & Minister'),
('PC Mohan',          'mp', 'BJP',  'Bengaluru Central','Karnataka','Bengaluru','560001',null,null,'Member of Parliament, Lok Sabha'),
('Tejasvi Surya',     'mp', 'BJP',  'Bengaluru South','Karnataka','Bengaluru','560038',null,null,'Member of Parliament, Lok Sabha'),
('Shobha Karandlaje', 'mp', 'BJP',  'Bengaluru North','Karnataka','Bengaluru','560011',null,null,'Member of Parliament & Union Minister, Lok Sabha'),
('DK Suresh',         'mp', 'INC',  'Bengaluru Rural','Karnataka','Bengaluru','560066',null,null,'Member of Parliament, Lok Sabha'),
-- Chennai MLAs & MPs
('Udhayanidhi Stalin','mla','DMK',  'Chepauk-Thiruvallikeni','Tamil Nadu','Chennai','600005',null,null,'MLA & Deputy Chief Minister, Tamil Nadu'),
('J Anbazhagan',      'mla','DMK',  'Harbour',              'Tamil Nadu','Chennai','600001',null,null,'MLA'),
('Dayanidhi Maran',   'mp', 'DMK',  'Chennai Central',      'Tamil Nadu','Chennai','600002',null,null,'Member of Parliament, Lok Sabha'),
('T Sumathy',         'mp', 'DMK',  'Chennai South',        'Tamil Nadu','Chennai','600020',null,null,'Member of Parliament, Lok Sabha'),
('R Sudhir',          'mp', 'DMK',  'Chennai North',        'Tamil Nadu','Chennai','600007',null,null,'Member of Parliament, Lok Sabha');

-- Seed councillors
INSERT INTO public.representatives
  (name, type, party, constituency, city, ward, role)
VALUES
-- Mumbai BMC councillors
('Ritu Tawde',         'councillor','BJP',       'Ward A-1','Mumbai','Andheri West',    'BMC Councillor'),
('Priya Shah',         'councillor','NCP',       'Ward H/W','Mumbai','Bandra West',     'BMC Councillor'),
('Suresh More',        'councillor','Shiv Sena', 'Ward R/N','Mumbai','Dahisar',         'BMC Councillor'),
('Sunita Rane',        'councillor','BJP',       'Ward K/W','Mumbai','Malad West',      'BMC Councillor'),
('Rajesh Pardeshi',    'councillor','Shiv Sena', 'Ward T',  'Mumbai','Mulund',          'BMC Councillor'),
('Meera Jadhav',       'councillor','NCP',       'Ward N',  'Mumbai','Ghatkopar',       'BMC Councillor'),
('Anil Kokate',        'councillor','BJP',       'Ward S',  'Mumbai','Borivali',        'BMC Councillor'),
('Vimla Nair',         'councillor','Shiv Sena', 'Ward P/S','Mumbai','Goregaon',        'BMC Councillor'),
('Mahesh Sawant',      'councillor','BJP',       'Ward P/N','Mumbai','Santacruz',       'BMC Councillor'),
('Kavita Desai',       'councillor','INC',       'Ward D',  'Mumbai','Worli',           'BMC Councillor'),
('Sanjay Patil',       'councillor','Shiv Sena', 'Ward L',  'Mumbai','Kurla',           'BMC Councillor'),
('Rekha Bhosale',      'councillor','BJP',       'Ward B',  'Mumbai','Malabar Hill',    'BMC Councillor'),
-- Pune PMC councillors
('Abhishek Jadhav',    'councillor','NCP',       'Ward 1',  'Pune','Kothrud',           'PMC Councillor'),
('Pratibha Kulkarni',  'councillor','BJP',       'Ward 5',  'Pune','Shivajinagar',      'PMC Councillor'),
('Sachin Kale',        'councillor','INC',       'Ward 12', 'Pune','Hadapsar',          'PMC Councillor'),
-- Delhi MCD councillors
('Rajesh Kumar',       'councillor','AAP',       'Ward 101','Delhi','Malviya Nagar',    'MCD Councillor'),
('Anita Sharma',       'councillor','BJP',       'Ward 201','Delhi','Patel Nagar',      'MCD Councillor'),
('Rohan Gupta',        'councillor','AAP',       'Ward 85', 'Delhi','Greater Kailash',  'MCD Councillor'),
-- Bengaluru BBMP councillors
('Srikanth Reddy',     'councillor','INC',       'Ward 67', 'Bengaluru','BTM Layout',   'BBMP Councillor'),
('Kamala Devi',        'councillor','BJP',       'Ward 12', 'Bengaluru','Malleswaram',   'BBMP Councillor'),
('Venkat Swamy',       'councillor','INC',       'Ward 44', 'Bengaluru','Shivajinagar', 'BBMP Councillor'),
-- Chennai GCC councillors
('Selvam Kumar',       'councillor','DMK',       'Ward 108','Chennai','T.Nagar',        'GCC Councillor'),
('Priya Mohan',        'councillor','DMK',       'Ward 169','Chennai','Velachery',      'GCC Councillor'),
('Murugan Raja',       'councillor','DMK',       'Ward 78', 'Chennai','Royapuram',      'GCC Councillor');
