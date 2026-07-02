-- Create the storage bucket for KYC documents if it does not already exist
insert into storage.buckets (id, name, public)
values ('kyc_documents', 'kyc_documents', true)
on conflict (id) do nothing;

-- Set up Row Level Security (RLS) policies for the bucket
-- Allow authenticated users to upload documents to a path matching their owner_id
create policy "Owners can upload KYC documents"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'kyc_documents' 
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to read their own KYC documents
create policy "Owners can view their own KYC documents"
on storage.objects for select
to authenticated
using (
    bucket_id = 'kyc_documents' 
    and (storage.foldername(name))[1] = auth.uid()::text
);
