#include <iostream>
#include <stdio.h>
#include <cuda.h>

#define max_N 100000
#define max_P 30
#define BLOCKSIZE 1024

using namespace std;

//*******************************************
/*
Approach : Here in this question we need to find number of successful request at a center and number of unsuccesful request at center
and Number of success request and Number of failure from total request. Here first I have create a slot array which will store all the slots
and their corresponding capacity , we have also calculate the offset for every capacity and facilities. After creating the slots array we have call a kernel.
Now in kernel call for every thread in parallel we have done the parallel computation center and facility wise. 
At last we have store the computation.
*/
__global__ void all(int N,int R, int* d_center, int* d_facility, int* d_facids, int* d_capacity, int* d_offset, int *d_reqid, int *d_reqcen, int *d_reqfac, int *d_reqstart, int *d_reqslots, int* d_totalreqs, int* d_succesreqs, int* d_slots, int* d_success, int* d_failure,int np)
{
    int blockId = blockIdx.x * blockDim.x;
    int id = blockId + threadIdx.x; //Calculating the threadId
    bool flag;
    if(id < np) // If our id is smaller then N*max_P
    {
      
        for(int k = 0; k < R; k++)// Then traverse for maximum all the resources and do computation only when its mataches its center and facility ids
        {
            flag = true;
            int cenfac = d_reqcen[k] * 30;
            int dfac = d_reqfac[k];
            int res = cenfac + dfac ;// If we find then that our reqcen and reqfac matches then we can do the computation
            int count = 0; 
            if(res== id)
            {
                int temp = d_reqstart[k] + d_reqslots[k];
                if(temp<=25) // It will work at maximum for 25 if reqstart and reqslots is greater then 25 it means it can be given access so just make it false
                {   
                    cenfac  = d_reqcen[k] * 30;
                    dfac = d_reqfac[k];
                    int cenfacres = cenfac+ dfac;
                    int slotstart = (cenfacres) * 24 + d_reqstart[k];  // Starting position for every slot
                    for(int i = 0; i < d_reqslots[k]; i++) // It will traverse at maximum of number of requested slots
                    {
                        if(d_slots[ slotstart + i-1]>0)//If this slots is not empty then we can decrease the capacity
                        {              
                              atomicSub(&d_slots[slotstart + i-1], 1); // Now decrease the capacity
                        }
                        else
                        {
                            int j=0;
                            while(j<i)
                            {
                                atomicAdd(&d_slots[slotstart + j-1], 1); // Now for the request which slots fails, we need to increase the slots in which it has earlier decreses
                                j++;
                            }
                            flag = false;
                            break;
                        }
                        
                    }
                }
                else
                {
                    count++;
                    flag = false;
                }

    
                if (flag) {
                  atomicAdd(&d_success[0], 1); //Atomic add the number of success request
                  atomicAdd(&d_succesreqs[d_reqcen[k]], 1); // Atomic add the number of success request at a center
        }     else {
                  atomicAdd(&d_failure[0], 1); // Atomic add the number of failures at a center
        }
            }

            
        }

        
    }

}


//***********************************************


int main(int argc,char **argv)
{
	// variable declarations...
    int N,*centre,*facility,*capacity,*fac_ids, *succ_reqs, *tot_reqs,*slots;
    

    FILE *inputfilepointer;
    
    //File Opening for read
    char *inputfilename = argv[1];
    inputfilepointer    = fopen( inputfilename , "r");

    if ( inputfilepointer == NULL )  {
        printf( "input.txt file failed to open." );
        return 0; 
    }

    fscanf( inputfilepointer, "%d", &N ); // N is number of centres
	    int *offset = (int *) malloc ( (N) * sizeof (int) ); /// This will store the offset from where next capacity is starting and so on
    // Allocate memory on cpu
    centre=(int*)malloc(N * sizeof (int));  // Computer  centre numbers
    facility=(int*)malloc(N * sizeof (int));  // Number of facilities in each computer centre
    fac_ids=(int*)malloc(max_P * N  * sizeof (int));  // Facility room numbers of each computer centre
    capacity=(int*)malloc(max_P * N *  sizeof (int));  // stores capacities of each facility for every computer centre 
    slots=(int*)malloc(max_P * N * 24 * sizeof (int));  // It will store the slots on which we can work for every facility there are 24 slots available and there can be maximum of 
    // 30 facility at a center

    int success=0;  // total successful requests
    int fail = 0;   // total failed requests
    tot_reqs = (int *)malloc(N*sizeof(int));   // total requests for each centre
    succ_reqs = (int *)malloc(N*sizeof(int)); // total successful requests for each centre

    // Input the computer centres data
    int k1=0 , k2 = 0,k3=0;
    for(int i=0;i<N;i++)
    {
      k3 = 0;
      fscanf( inputfilepointer, "%d", &centre[i] );
      fscanf( inputfilepointer, "%d", &facility[i] );
      offset[i]=k1;// Storing offset for every center how many facilities its need to move
      
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &fac_ids[k1] );
        k1++;
      }
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &capacity[k2]);
        for(int k4=0;k4<24;k4++){
            int index = centre[i]*30*24;
            slots[index + k3]=capacity[k2];
            k3++;
        }
        k2++; 
        
      }
    }

    // variable declarations
    int *req_id, *req_cen, *req_fac, *req_start, *req_slots;   // Number of slots requested for every request
    
    // Allocate memory on CPU 
	  int R;
	fscanf( inputfilepointer, "%d", &R); // Total requests
    req_id = (int *) malloc ( (R) * sizeof (int) );  // Request ids
    req_cen = (int *) malloc ( (R) * sizeof (int) );  // Requested computer centre
    req_fac = (int *) malloc ( (R) * sizeof (int) );  // Requested facility
    req_start = (int *) malloc ( (R) * sizeof (int) );  // Start slot of every request
    req_slots = (int *) malloc ( (R) * sizeof (int) );   // Number of slots requested for every request
    
    // Input the user request data
    for(int j = 0; j < R; j++)
    {
       fscanf( inputfilepointer, "%d", &req_id[j]);
       fscanf( inputfilepointer, "%d", &req_cen[j]);
       fscanf( inputfilepointer, "%d", &req_fac[j]);
       fscanf( inputfilepointer, "%d", &req_start[j]);
       fscanf( inputfilepointer, "%d", &req_slots[j]);
       tot_reqs[req_cen[j]]+=1;  
    }

     int np = max_P * N;
   	int *d_center, *d_facility, *d_facids , *d_capacity , *d_offset , *d_reqid, *d_reqcen, *d_reqfac, *d_reqstart, *d_reqslots, *d_slots, *d_totalreqs, *d_succesreqs,*d_success,*d_failure;
    cudaMalloc(&d_center, (N) * sizeof(int)); // It will store the centers in device
    cudaMemcpy(d_center, centre, N * sizeof(int), cudaMemcpyHostToDevice);

	  cudaMalloc(&d_facility, (N) * sizeof(int));//It will store the facility in the device
    cudaMemcpy(d_facility, facility, N * sizeof(int), cudaMemcpyHostToDevice);

  	cudaMalloc(&d_facids, (max_P*N) * sizeof(int)); // It will store the facids in the device
    cudaMemcpy(d_facids, fac_ids, max_P * N * sizeof(int), cudaMemcpyHostToDevice);

	  cudaMalloc(&d_capacity, (max_P*N) * sizeof(int)); // It will store the capacity for every facility of the centers
	  cudaMemcpy(d_capacity, capacity, max_P * N * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_offset, (N) * sizeof(int)); // It will store the offset
	  cudaMemcpy(d_offset, offset,  N * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_reqid, (R) * sizeof(int)); // It will store the Request Id
    cudaMemcpy(d_reqid, req_id, R * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_reqcen, (R) * sizeof(int)); // It will store the Request center
	  cudaMemcpy(d_reqcen, req_cen, R * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_reqfac, (R) * sizeof(int)); // It will store the request facility Id
	  cudaMemcpy(d_reqfac, req_fac, R * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_reqstart, (R) * sizeof(int)); // It will store the starting time of request
    cudaMemcpy(d_reqstart, req_start, R * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_reqslots, (R) * sizeof(int)); // It will store the number of required slots
    cudaMemcpy(d_reqslots, req_slots, R * sizeof(int), cudaMemcpyHostToDevice);

	  cudaMalloc(&d_slots, (max_P*N*24) * sizeof(int)); // It will store the for every facility and center slots
	  cudaMemcpy(d_slots, slots, N*max_P*24 * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_totalreqs, (N) * sizeof(int)); // It will store the total request at the center
    cudaMemcpy(d_totalreqs, tot_reqs, N * sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_succesreqs, (N) * sizeof(int)); // It will store the number of success request from center
    cudaMalloc(&d_succesreqs, (N) * sizeof(int)); 

    cudaMalloc(&d_success,sizeof(int)); // It will return number of successful request
    cudaMemcpy(d_success, &success, sizeof(int), cudaMemcpyHostToDevice);

    cudaMalloc(&d_failure,  sizeof(int)); // It will return number of failure
    cudaMemcpy(d_failure, &fail,sizeof(int), cudaMemcpyHostToDevice);  
 
    
    // Output
    //*********************************
    // Call the kernels here
    //********************************
  
    all<<<np, 1024>>>(N, R, d_center, d_facility, d_facids, d_capacity, d_offset, d_reqid, d_reqcen, d_reqfac, d_reqstart, d_reqslots, d_totalreqs, d_succesreqs, d_slots, d_success, d_failure,np); 
    
    cudaMemcpy(succ_reqs,d_succesreqs, N * sizeof(int), cudaMemcpyDeviceToHost);  
    cudaMemcpy(&fail, d_failure, sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(&success, d_success, sizeof(int), cudaMemcpyDeviceToHost);
    char *outputfilename = argv[2]; 
    FILE *outputfilepointer;
    outputfilepointer = fopen(outputfilename,"w");
    
    fprintf( outputfilepointer, "%d %d\n", success, fail);
    for(int j = 0; j < N; j++)
    {
      fprintf( outputfilepointer, "%d %d\n", succ_reqs[j], tot_reqs[j]-succ_reqs[j]);
    }
    fclose( inputfilepointer );
    fclose( outputfilepointer );
    cudaDeviceSynchronize();
	return 0;
}